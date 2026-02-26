{ pkgs, ... }:
{
    users.users.kiosk = {
    isNormalUser = true;
    description = "Kiosk User";
    createHome = true;           
    home = "/home/kiosk";
  };
}
