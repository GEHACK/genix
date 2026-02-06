{ pkgs, ... }:
{
  networking = {
    hostName = "geproxy";
    useDHCP = false;
    wireless = {
      enable = true;
      # password can be hardcoded, only works with geproxy mac
      networks."iotroam".psk = "gehackgehack";
    };

    bridges = {
      "br-admin" = {
        interfaces = [
          "eno1"
          "eno2"
        ];
      };
      "br-contest" = {
        interfaces = [
          "eno3"
          "eno4"
          "eno5"
          "eno6"
        ];
      };
    };

    interfaces = {
      "wlp6s0".useDHCP = true;

      "br-contest" = {
        ipv4.addresses = [
          {
            address = "192.168.1.1";
            prefixLength = 24;
          }
        ];
      };

      "br-admin" = {
        ipv4.addresses = [
          {
            address = "192.168.2.1";
            prefixLength = 24;
          }
        ];
      };
    };

    firewall.enable = false;
    nftables = {
      enable = true;
      checkRuleset = true;
      rulesetFile = ./assets/firewall.nft;
    };

  };
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # add scripts to enable and disable internet for the contest brige
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "enable-internet" ''
      set -euo pipefail
      nft flush chain inet filter contest_inet
      nft add rule inet filter contest_inet counter accept
      echo -n "Contest internet ENABLED"
    '')

    (pkgs.writeShellScriptBin "disable-internet" ''
      set -euo pipefail
      nft flush chain inet filter contest_inet
      echo -n "Contest internet DISABLED"
    '')
  ];
}
