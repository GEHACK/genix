{ config, ... }: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/teammachine
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    enableRedistributableFirmware = true;
    nvidia = {
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
  };
  
  services.xserver.videoDrivers = [ "nvidia" ];
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";  
  
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
