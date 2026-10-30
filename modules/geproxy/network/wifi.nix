{ lib, config, ... }:
let
  accessPoints = lib.filterAttrs (_: net: net.wifi != null) config.geproxy.networks;
in
{
  sops.secrets = lib.mapAttrs' (
    name: _: lib.nameValuePair "wifi.${name}" { restartUnits = [ "hostapd.service" ]; }
  ) accessPoints;

  services.hostapd = {
    enable = accessPoints != { };
    radios = lib.mapAttrs' (
      name: net:
      lib.nameValuePair net.wifi.interface {
        countryCode = "NL";
        channel = 6;
        networks.${net.wifi.interface} = {
          inherit (net.wifi) ssid;
          authentication.saePasswords = [ { passwordFile = config.sops.secrets."wifi.${name}".path; } ];
          settings.bridge = net.bridge;
        };
      }
    ) accessPoints;
  };

  systemd.services.hostapd = lib.mkIf (accessPoints != { }) {
    after = [ "systemd-networkd.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
