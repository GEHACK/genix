{ lib, config, ... }:
let
  inherit (config.geproxy) uplink networks;

  prefixLength = subnet: lib.toInt (lib.last (lib.splitString "/" subnet));
in
{
  networking = {
    useNetworkd = true;
    useDHCP = false;
    bridges = lib.mapAttrs' (
      _: net: lib.nameValuePair net.bridge { inherit (net) interfaces; }
    ) networks;
    interfaces =
      lib.mapAttrs' (
        _: net:
        lib.nameValuePair net.bridge {
          useDHCP = false;
          ipv4.addresses = [
            {
              inherit (net) address;
              prefixLength = prefixLength net.subnet;
            }
          ];
        }
      ) networks
      // {
        ${uplink.interface}.useDHCP = true;
      };
  };

  systemd.network = {
    wait-online.anyInterface = true;
    networks = lib.mapAttrs' (
      _: net:
      lib.nameValuePair "40-${net.bridge}" {
        networkConfig.ConfigureWithoutCarrier = true;
        linkConfig.RequiredForOnline = "no";
      }
    ) networks;
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      MulticastDNS = "yes";
      LLMNR = false;
    };
  };
}
