{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.teammachine.webcamstream;
in
{
  options.teammachine.webcamstream = {
    # Off by default: today the service is defined but never started on boot.
    enable = lib.mkEnableOption "VLC-based webcam HTTP stream";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "TCP port the webcam stream is served on.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/video0";
      example = "/dev/video1";
      description = "V4L2 capture device to stream.";
    };

    startOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the stream automatically at boot when enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.services.webcam-stream = {
      description = "Team Webcam Stream (VLC)";
      wantedBy = lib.optional cfg.startOnBoot "multi-user.target";
      after = [ "network.target" ];

      serviceConfig = {
        RuntimeDirectory = "webcam-stream";
        Environment = "HOME=/run/webcam-stream";

        ExecStart = ''
          ${pkgs.vlc}/bin/vlc -I dummy -q v4l2://${cfg.device}:chroma=mjpg:width=640:height=480:aspect-ratio="16:9" \
          :input-slave=alsa://plughw:0,0 \
          --sout "#transcode{vcodec=h264,vb=0,scale=0,fps=15,acodec=mpga,ab=128,channels=2}:http{mux=ts,dst=:${toString cfg.port}}"
        '';

        Restart = "always";
        RestartSec = "5s";

        DynamicUser = true;
        SupplementaryGroups = [
          "video"
          "audio"
        ];
        PrivateDevices = false;
      };
    };
  };
}
