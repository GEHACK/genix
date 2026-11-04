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

  gestreamer = pkgs.rustPlatform.buildRustPackage rec {
    pname = "cargo-aoc";
    version = "0.3.5";

    nativeBuildInputs = with pkgs; [
      rustPlatform.bindgenHook
      pkg-config
    ];
    buildInputs = with pkgs; [
      dbus
    ] ++ gstPackages;
    src = pkgs.fetchFromGitHub {
      owner = "GEHACK";
      repo = "contest-tools";
      rev = "967eb0d769fedd3dce73ae87fed2eec97f9cac19";
      hash = "sha256-Hu1rN6P0HHlTHEbXS3iOCbPcV48QpYrCxyi0ATPDgdE=";
    };
    cargoBuildFlags = [
      "--package"
      "gestreamer"
    ];
    cargoHash = "sha256-LbrhRvVrB9Fp02zLC13D30IGQOUSHRgTtivOLdHCIdU=";
    doCheck = false;
  };
in
{
  options.teammachine.streams = {
    enable = lib.mkEnableOption "The gestreamer streams server";

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

    encoder = lib.mkOption {
      type = lib.types.str;
      default = "x264enc key-int-max=12 ! h264parse";
      example = "vah265lpenc rate-control=vbr key-int-max=12 ! h265parse";
      description = "A gstreamer pipeline for encoding video.";
    };

    startOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the stream automatically at boot when enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ gestreamer ];

    systemd.user.services.gestreamer = {
      Unit = {
        Description = "The gestreamer stream service";
        After = [
          "network.target"
          "dbus.socket"
        ];
        PartOf = "gnome-session.target";
      };

      Service = {
        ExecStart = "${gestreamer}/bin/gestreamer -p ${toString cfg.port} -w '${cfg.webcam}' -e '${cfg.encoder}'";
        Restart = "always";
        RestartSec = "5s";
        PrivateDevices = false;

        Environment = [
          "GI_TYPELIB_PATH=${giTypelibPath}"
          "GST_PLUGIN_PATH=${gstPluginPath}"
          "GST_DEBUG=0"
        ];
      };

      Install = {
        WantedBy = lib.optional cfg.startOnBoot "gnome-session.target";
      };
    };
  };
}
