{ pkgs, ... }:
{
    users.users.kiosk = {
    isNormalUser = true;
    description = "Kiosk User";
    createHome = true;           
    home = "/home/kiosk";
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../fanout_pubkey ];
}
