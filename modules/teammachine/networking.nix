{ pkgs, ... }: {
  networking = {
    hostName = "team";
    useDHCP = false;
    wireless = {
      enable = false;
    };
    extraHosts = 
      ''
        10.1.0.1 judge
        10.1.0.1 docs
      '';
  };
}