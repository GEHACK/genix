{ pkgs, ... }: {
  networking = {
    hostName = "team";
    useDHCP = false;
    wireless = {
      enable = false;
    };
  };
}