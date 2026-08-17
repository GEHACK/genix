{ config, pkgs, ... }:
let
  bridge = "br-lan";
  bridgeAddress = "10.0.0.1";
in
{
  networking = {
    hostName = "geminecraft";
    useDHCP = false;
    useNetworkd = true;
    wireless = {
      enable = true;
      secretsFile = config.sops.secrets.wireless-uplink.path;
      networks."Wifi1301-5GHz".pskRaw = "ext:psk_uplink";
    };
    firewall.enable = false;
    nftables = {
      enable = true;
      checkRuleset = true;
      flushRuleset = false;
      rulesetFile = ./assets/firewall.nft;
      extraDeletions = ''
        table inet filter
        delete table inet filter
        table ip lanparty
        delete table ip lanparty
      '';
    };
  };

  sops.secrets.wireless-uplink = {
    group = "wpa_supplicant";
    mode = "0440";
    restartUnits = [ "wpa_supplicant.service" ];
  };

  systemd.network = {
    enable = true;
    netdevs."10-${bridge}".netdevConfig = {
      Name = bridge;
      Kind = "bridge";
    };
    networks = {
      "20-ethernet" = {
        matchConfig = {
          Type = "ether";
          Driver = "!veth !bridge !tun !tap";
        };
        networkConfig.Bridge = bridge;
      };
      "30-${bridge}" = {
        matchConfig.Name = bridge;
        address = [ "${bridgeAddress}/24" ];
        networkConfig.ConfigureWithoutCarrier = true;
      };
      "40-wireless" = {
        matchConfig.Type = "wlan";
        networkConfig.DHCP = "ipv4";
        dhcpV4Config.RouteMetric = 100;
      };
    };
  };

  services.dnsmasq = {
    resolveLocalQueries = false;
    enable = true;
    settings = {
      log-queries = true;
      log-dhcp = true;

      domain-needed = true;
      bogus-priv = true;

      bind-interfaces = true;
      interface = bridge;
      listen-address = bridgeAddress;

      dhcp-authoritative = true;
      domain = [ "lan.local,${bridge}" ];
      dhcp-range = [ "${bridge},10.0.0.50,10.0.0.250,255.255.255.0,infinite" ];
      dhcp-option = [
        "${bridge},3,${bridgeAddress}"
        "${bridge},6,${bridgeAddress}"
        "${bridge},42,${bridgeAddress}"
      ];

      address = [
        "/imaged.gehack.nl/${bridgeAddress}"
        "/minecraft.gehack.nl/${bridgeAddress}"
      ];
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "enable-internet" ''
      set -euo pipefail
      nft flush chain inet filter lan_inet
      nft add rule inet filter lan_inet counter accept
      echo -n "LAN internet ENABLED"
    '')
    (pkgs.writeShellScriptBin "disable-internet" ''
      set -euo pipefail
      nft flush chain inet filter lan_inet
      echo -n "LAN internet DISABLED"
    '')
  ];
}
