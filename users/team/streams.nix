{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.teammachine.streams;
  gstPackages = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    gst-vaapi
  ];
  gstPluginPackages = gstPackages ++ [
    pkgs.pipewire
  ];

  gstPluginPath =
  lib.makeSearchPathOutput
    "out"
    "lib/gstreamer-1.0"
    gstPluginPackages;
  giTypelibPath =
    lib.makeSearchPathOutput
      "out"
      "lib/girepository-1.0"
      gstPackages;

  pyPackages = pkgs.python3.withPackages (ps: with ps; [
    aiohttp
    dbus-next
    pygobject3
  ]);


  streams = pkgs.python3Packages.buildPythonApplication {
    pname = "streams";
    version = "0.0";
    format = "other";

    src = ./streams;

    propagatedBuildInputs = gstPackages ++ [
      pyPackages
    ];

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      install -Dm755 streams.py $out/bin/streams
    '';

    meta = with lib; {
      mainProgram = "streams";
    };
  };
in
{
  options.teammachine.streams = {
    enable = lib.mkEnableOption "Python streams server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "TCP port the webcam stream is served on.";
    };

    webcam = lib.mkOption {
      type = lib.types.str;
      default = "/dev/video0";
      example = "/dev/video1";
      description = "V4L2 webcam capture device to stream.";
    };

    startOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the stream automatically at boot when enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ streams ];

    systemd.user.services.streams = {
      Unit = {
        Description = "Python stream service";
        After = [ "network.target" ];
      };

      Service = {
        ExecStart = "${streams}/bin/streams";
        Restart = "always";
        RestartSec = "5s";
        PrivateDevices = false;

        Environment = [
          "GI_TYPELIB_PATH=${giTypelibPath}"
          "GST_PLUGIN_PATH=${gstPluginPath}"
        ];
      };

      Install = {
        WantedBy = lib.optional cfg.startOnBoot "default.target";
      };
    };
  };
}
