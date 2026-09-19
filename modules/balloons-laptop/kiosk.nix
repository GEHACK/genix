{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.balloons;

  # Chromium ignores --kiosk under ozone-wayland; --app is what drops the tab
  # strip and omnibox.
  start-kiosk = pkgs.writeShellScript "start-balloons-kiosk" ''
    exec ${lib.getExe pkgs.chromium} \
      --app="${cfg.url}" \
      --start-fullscreen \
      --ozone-platform=wayland \
      --user-data-dir=/tmp/balloons-kiosk \
      --no-first-run \
      --no-default-browser-check \
      --disable-session-crashed-bubble \
      --disable-features=Translate \
      --password-store=basic
  '';
in
{
  options.balloons.url = lib.mkOption {
    type = lib.types.str;
    default = "https://balloons.gehack.nl";
    description = "Page the kiosk browser opens full screen on boot.";
  };

  config = {
    fonts.enableDefaultPackages = true;

    networking.dhcpcd.wait = "ipv4";

    services.cage = {
      enable = true;
      user = "kiosk";

      program = "${start-kiosk}";

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
