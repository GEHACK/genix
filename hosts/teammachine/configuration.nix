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

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };

  hardware.enableRedistributableFirmware = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";

      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  system.stateVersion = "25.11";
}
