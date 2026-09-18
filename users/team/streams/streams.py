#!/usr/bin/env python3
import argparse
import signal
from asyncio.queues import QueueShutDown

import asyncio
import gi
from aiohttp import web
from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import BusType

gi.require_version("Gst", "1.0")
from gi.repository import GLib, Gst

Gst.init(None)

loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)

BUS_NAME = "org.gnome.Mutter.ScreenCast"
SCREENCAST_PATH = "/org/gnome/Mutter/ScreenCast"
DISPLAYCONF_PATH = "/org/gnome/Mutter/DisplayConfig"

SCREENCAST_IFACE = "org.gnome.Mutter.ScreenCast"
SESSION_IFACE = "org.gnome.Mutter.ScreenCast.Session"
STREAM_IFACE = "org.gnome.Mutter.ScreenCast.Stream"
PROPERTIES_IFACE = "org.freedesktop.DBus.Properties"
DISPLAYCONFIG_IFACE = "org.gnome.Mutter.DisplayConfig"

parser = argparse.ArgumentParser(
                    prog='streams',
                    description='Stream screencast and webcam using MPEG-TS')

parser.add_argument('-p', '--port', type=int, default=8080)
parser.add_argument('-w', '--webcam', default='/dev/video0')
parser.add_argument('-e', '--encoder', default='x264enc key-int-max=12 ! h264parse')
args = parser.parse_args()

async def get_primary_monitor_name():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    introspection = await bus.introspect(
        DISPLAYCONFIG_IFACE,
        DISPLAYCONF_PATH,
    )

    proxy = bus.get_proxy_object(
        DISPLAYCONFIG_IFACE,
        DISPLAYCONF_PATH,
        introspection,
    )

    display_config = proxy.get_interface(DISPLAYCONFIG_IFACE)
    _serial, _monitors, logical_monitors, _properties = await display_config.call_get_current_state()

    for logical_monitor in logical_monitors:
        _x, _y, _scale, _transform, primary, monitor_specs, _properties = logical_monitor

        if primary:
            connector, _vendor, _product, _serial = monitor_specs[0]
            return connector

    return None

async def start_screencast():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    # Main screencast object.
    introspection = await bus.introspect(BUS_NAME, SCREENCAST_PATH)
    proxy = bus.get_proxy_object(BUS_NAME, SCREENCAST_PATH, introspection)
    screencast = proxy.get_interface(SCREENCAST_IFACE)

    session_path = await screencast.call_create_session({})

    # Session object.
    introspection = await bus.introspect(BUS_NAME, session_path)
    proxy = bus.get_proxy_object(BUS_NAME, session_path, introspection)
    session = proxy.get_interface(SESSION_IFACE)

    monitor_name = await get_primary_monitor_name()
    print(f"Casting monitor: {monitor_name}", flush=True)
    stream_path = await session.call_record_monitor(
        monitor_name,
        {
            "cursor-mode": Variant("u", 1),
            "is-recording": Variant("b", True),
        },
    )

    # Stream object.
    introspection = await bus.introspect(BUS_NAME, stream_path)
    proxy = bus.get_proxy_object(BUS_NAME, stream_path, introspection)
    stream = proxy.get_interface(STREAM_IFACE)

    node_id_future = asyncio.get_running_loop().create_future()

    def pipewire_stream_added(node_id):
        node_id = int(node_id)
        print("PipeWire node:", node_id, flush=True)

        if not node_id_future.done():
            node_id_future.set_result(node_id)

    stream.on_pipe_wire_stream_added(pipewire_stream_added)

    # This causes Mutter to create the PipeWire stream and emit the signal.
    await session.call_start()
    print("Screencast started", flush=True)

    node_id = await node_id_future

    return node_id


def on_new_sample(queues, sink):
    sample = sink.emit("pull-sample")
    if sample is None:
        return Gst.FlowReturn.ERROR

    buffer = sample.get_buffer()
    success, map_info = buffer.map(Gst.MapFlags.READ)

    if success:
        data = bytes(map_info.data)
        buffer.unmap(map_info)

        # Wake all HTTP clients from the GStreamer thread.
        for queue in set(queues):
            loop.call_soon_threadsafe(queue.put_nowait, data)

    return Gst.FlowReturn.OK


def create_pipeline(
    src: str,
    encoder: str,
    audio: bool = False,
) -> (Gst.Pipeline, set[asyncio.Queue]):

    launch = f"""
    {src} !
    videoconvert !
    {encoder} !
    queue !
    mpegtsmux name=mux !
    appsink name=ts_sink
            emit-signals=true
            sync=false
            max-buffers=100
    """
    if audio:
        launch = launch + """
        pipewiresrc on-disconnect=eos !
        audioconvert !
        audioresample !
        audio/x-raw,rate=48000 !
        fdkaacenc !
        aacparse !
        queue !
        mux.
        """

    pipeline = Gst.parse_launch(launch)
    if audio:
        # Force a pipeline clock to prevent clock issues between video and audio clocks
        pipeline.use_clock(Gst.SystemClock.obtain())
        pipeline.set_start_time(Gst.CLOCK_TIME_NONE)

    queues = set()
    sink = pipeline.get_by_name("ts_sink")
    sink.connect("new-sample", lambda sink: on_new_sample(queues, sink))
    pipeline.set_state(Gst.State.PLAYING)
    return (pipeline, queues)


async def handle_stream_request(request, queues):
    response = web.StreamResponse(
        status=200,
        headers={
            "Content-Type": "video/mp2t",
            "Cache-Control": "no-cache",
            "Connection": " keep-alive",
            "Access-Control-Allow-Origin": "*",
        },
    )

    await response.prepare(request)

    queue = asyncio.Queue(maxsize=1000)
    queues.add(queue)

    try:
        while True:
            data = await queue.get()
            await response.write(data)
    except (asyncio.CancelledError, ConnectionResetError, BrokenPipeError, QueueShutDown):
        pass
    finally:
        queues.discard(queue)

    return response


app = web.Application()

pipewire_node_id = asyncio.run(start_screencast())
(screencast_pipeline, screencast_queues) = create_pipeline(
    src=f"pipewiresrc on-disconnect=eos path={pipewire_node_id} keepalive-time=100",
    encoder=args.encoder
)
app.router.add_get(
    "/screencast.ts",
    lambda request: handle_stream_request(request, screencast_queues)
)

(webcam_pipeline, webcam_queues) = create_pipeline(
    src=f"v4l2src device={args.webcam} ! decodebin",
    encoder=args.encoder,
    audio=True
)
app.router.add_get(
    "/webcam.ts",
    lambda request: handle_stream_request(request, webcam_queues)
)


def terminate(*_):
    print("Terminating stream service...", flush=True)
    for (pipeline, queues) in [(screencast_pipeline, screencast_queues), (webcam_pipeline, webcam_queues)]:
        if pipeline is not None:
            pipeline.set_state(Gst.State.NULL)
            for queue in queues:
                queue.shutdown(immediate=True)
    loop.stop()
    exit(0)

signal.signal(signal.SIGINT, terminate)
signal.signal(signal.SIGTERM, terminate)

web.run_app(app, port=args.port, loop=loop, handle_signals=False)
