{ config, lib, pkgs, ... }:
let
  icpc-presentation = pkgs.callPackage ./scoreboard.nix {};
  cdsURL = "https://cds.bartjan.tech/api/contests/";
  contestID = "demo";

  start-presentation = pkgs.writeShellScript "start-presentation" ''
    # Read the contents of the sops-nix secret files
    USERNAME=$(cat ${config.sops.secrets."cds.presentation-client.username".path})
    PASSWORD=$(cat ${config.sops.secrets."cds.presentation-client.password".path})
    
    # Execute the client, replacing the shell process
    exec ${icpc-presentation}/bin/presentation-client "${cdsURL}${contestID}" "$USERNAME" "$PASSWORD"
  '';
in  
{
  sops.secrets = { 
    "cds.presentation-client.username" = {
      owner = config.services.cage.user; 
    };
    "cds.presentation-client.password" = {
      owner = config.services.cage.user; 
    };
  };

  systemd.network.wait-online.enable = true;

  services.cage = {
    enable = true;
    user = "kiosk";
    
    program = "${start-presentation}";
    
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
}
