{ config, pkgs, ... }: {
  imports = [
    ./disko.nix
    ./features.nix
    ../../modules
    ../../modules/teammachine
  ];

  teammachine.netboot = {
    pxe.enable = true;
    imaged.enable = true;
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

  system.stateVersion = "25.11";
}
