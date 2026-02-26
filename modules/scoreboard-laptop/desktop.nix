{ config, lib, pkgs, ... }:

let
  icpc-presentation = pkgs.callPackage ./scoreboard.nix {};
  cdsURL = "https://cds.bartjan.tech/api/contests/";
  contestID = "demo";
  presentationUsername = "presentation";
  presentationPassword = "gehack";
in  
{

  systemd.network.wait-online.enable = true;
  services.cage = {
    enable = true;
    user = "kiosk";
    
    program = "${icpc-presentation}/bin/presentation-client ${cdsURL}${contestID} ${presentationUsername} ${presentationPassword}";
    environment = {
      WL_DISPLAY = "wayland-0";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "cage";
    };
  };

  systemd.services."cage-tty1" = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
      PrivateTmp = true;
    };
  };

  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  
  environment.systemPackages = [ 
    pkgs.cage
    icpc-presentation 
  ];
}