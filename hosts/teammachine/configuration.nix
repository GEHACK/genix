{ config, ... }: {
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
        kotlin.enable = false;
      };
      neovim.enable = true;
      ides.enable = true;
      ides.jetbrains.enable = true; 
      submit.enable = true; 
      games.enable = true;
      misc-packages.enable = true; 
    };

    users.gehack = {
      neovim.enable = true;
    };
  };

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
  
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
