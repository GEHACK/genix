{ config, pkgs, ... }: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/teammachine
  ];

  teammachine = {
    users.team = {
      languages = {
        c.enable = true;
        cpp.enable = true;
        python.enable = true;
        java.enable = true;
        kotlin.enable = true;
      };
      neovim.enable = true;
      firefox.enable = true;
      ides.enable = true;
      ides.jetbrains.enable = true;
      submit.enable = true;
      games.enable = true;
      misc-packages.enable = true;
      trackpad.enable = true;

      streams = {
        enable = false;
        encoder = "vah264enc rate-control=vbr key-int-max=12 ! h264parse";
        webcam = "/dev/video0";
      };
    };
    printer.enable = true;

    netboot = {
      pxe.enable = true;
      imaged.enable = true;
    };
    remoteDesktop.enable = true;

    users.gehack = {
      neovim.enable = true;
      firefox.enable = true;
      trackpad.enable = true;
    };
    usbguard.enable = true;
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = [ pkgs.intel-media-driver ];
    };
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  # nixpkgs only loads the NVIDIA KMS modules when services.xserver.enable is set,
  # which it isn't (Weston greeter + GNOME Wayland). Without nvidia_drm, outputs on
  # the dGPU stay dark. i915 is added in modules/teammachine/boot.nix.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
