_: {
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

      "br-admin".useDHCP = true;

      "br-contest" = {
        ipv4.addresses = [
          {
            address = "192.168.10.1";
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
  };
}
