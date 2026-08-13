{ pkgs, ... }:
{
  networking = {
    hostName = "geproxy";
    useDHCP = false;
    wireless = {
      enable = true;
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
        useDHCP = false;
        ipv4 = {
          addresses = [
            {
              address = "10.0.0.1";
              prefixLength = 24;
            }
          ];
        };
      };
      "br-admin" = {
        useDHCP = false;
        ipv4 = {
          addresses = [
            {
              address = "10.0.1.1";
              prefixLength = 24;
            }
          ];
        };
      };
    };
    firewall.enable = false;
    nftables = {
      enable = true;
      checkRuleset = true;
      rulesetFile = ./assets/firewall.nft;
    };
  };

  users.users.dnsmasq = {
    isSystemUser = true;
    group = "dnsmasq";
    uid = 995;
  };
  users.groups.dnsmasq = {
    gid = 995;
  };

  # dnsmasq configuration
  services.dnsmasq = {
    resolveLocalQueries = false;
    enable = true;
    settings = {
      # Logging
      log-queries = true;
      log-dhcp = true;

      domain-needed = true;
      bogus-priv = true;

      bind-interfaces = true;
      interface = [
        "br-contest"
        "br-admin"
      ];
      except-interface = "wlp6s0";

      # TFTP chainloads iPXE; iPXE then fetches the imaged boot script over HTTP.
      enable-tftp = true;
      tftp-root = "${pkgs.ipxe}";

      # DHCP
      dhcp-authoritative = true;

      # Listen addresses
      listen-address = [
        "10.0.0.1"
        "10.0.1.1"
      ];

      # Domains
      domain = [
        "contest.local,br-contest"
      ];

      # DHCP ranges
      dhcp-range = [
        "br-contest,10.0.0.50,10.0.0.250,255.255.255.0,infinite"
        "br-admin,10.0.1.50,10.0.1.250,255.255.255.0,infinite"
      ];

      # DHCP options
      dhcp-option = [
        # Contest: captive, everything through 10.0.0.1
        "br-contest,3,10.0.0.1"
        "br-contest,6,10.0.0.1"
        "br-contest,42,10.0.0.1"
        # Admin: real gateway + public DNS so it bypasses dnsmasq
        "br-admin,3,10.0.1.1"
        "br-admin,6,8.8.8.8,1.1.1.1"
        "br-admin,42,10.0.1.1"
      ];

      # DNS addresses
      address = [
        "/judge.gehack.nl/10.0.0.1"
        "/imaged.gehack.nl/10.0.0.1"
        "/loom.gehack.nl/10.0.0.1"
        "/cds.gehack.nl/10.0.0.1"
        "/docs.gehack.nl/10.0.0.1"
      ];

      # PXE/imaged boot configuration
      dhcp-userclass = "set:ipxe,iPXE";
      dhcp-match = [
        "set:bios,60,PXEClient:Arch:00000"
        "set:efi32,60,PXEClient:Arch:00006"
        "set:efibc,60,PXEClient:Arch:00007"
        "set:efi64,60,PXEClient:Arch:00009"
      ];
      dhcp-boot = [
        "tag:!ipxe,tag:bios,undionly.kpxe,,10.0.0.1"
        "tag:!ipxe,tag:efi32,ipxe.efi,,10.0.0.1"
        "tag:!ipxe,tag:efibc,ipxe.efi,,10.0.0.1"
        "tag:!ipxe,tag:efi64,ipxe.efi,,10.0.0.1"
        "tag:ipxe,http://10.0.0.1:8080/boot/boot.ipxe"
      ];

      dhcp-host = [
        "b0:0c:d1:de:f0:0d,10.0.0.10,infinite"
        "02:20:d7:6f:20:cc,10.0.0.11,infinite"
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
      nft flush chain inet filter contest_inet
      nft add rule inet filter contest_inet counter accept
      echo -n "Contest internet ENABLED"
    '')
    (pkgs.writeShellScriptBin "disable-internet" ''
      set -euo pipefail
      nft flush chain inet filter contest_inet
      echo -n "Contest internet DISABLED"
    '')
    (pkgs.writeShellScriptBin "wol" ''
      count=0
      while read -r timestamp mac ip hostname clientid; do
        [[ -z "$mac" || "$mac" == "#"* ]] && continue
        ${pkgs.wakeonlan}/bin/wakeonlan "$mac" -i 10.0.0.255 > /dev/null 2>&1
        ((count++))
      done < "/var/lib/dnsmasq/dnsmasq.leases"

      echo "Done. Sent $count WOL packet(s)."
    '')

  ];
}
