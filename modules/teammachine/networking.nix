{ pkgs, ... }: {
  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts = 
      ''
        127.0.0.1 docs
      '';
  };
  
  boot.blacklistedKernelModules = [ "iwlwifi" "btusb" ];
}