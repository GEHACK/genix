{ pkgs, ... }: {
  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts = 
      ''
        10.1.0.1 judge
        10.1.0.1 docs
      '';
  };
  
  boot.blacklistedKernelModules = [ "iwlwifi" "btusb" ];
}