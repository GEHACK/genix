{ config, lib, pkgs, ... }:
let
  cfg = config.scoreboard;
  icpc-presentation = pkgs.callPackage ./scoreboard.nix {};

  start-presentation = pkgs.writeShellScript "start-presentation" ''
    USERNAME=$(cat ${config.sops.secrets."cds.presentation-client.username".path})
    PASSWORD=$(cat ${config.sops.secrets."cds.presentation-client.password".path})

    exec ${icpc-presentation}/bin/presentation-client "${cfg.cdsUrl}/api/contests/${cfg.contestId}" "$USERNAME" "$PASSWORD"
  '';
in
{
  options.scoreboard = {
    cdsUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cds.gehack.nl";
      description = "Base URL of the Contest Data Server, without trailing slash.";
    };

    contestId = lib.mkOption {
      type = lib.types.str;
      example = "fpcs2026";
      description = "CDS contest ID the presentation client connects to. Set this per contest.";
    };
  };

  config = {
    fonts.enableDefaultPackages = true;

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
  };
}
