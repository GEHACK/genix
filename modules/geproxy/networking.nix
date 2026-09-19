{
  pkgs,
  lib,
  config,
  geproxy_ip,
  contest_subnet,
  admin_ip,
  admin_subnet,
  imaged_port,
  cds_port,
  ...
}:
let
  cfg = config.geproxy.network;
  adminEnabled = cfg.admin.enable;

  contestBridge = "br-contest";
  adminBridge = "br-admin";
  dnsmasqId = 995;
  dnsmasqAdminId = 994;

  uplinkResolvConf = "/run/systemd/resolve/resolv.conf";

  imagedUrl = "http://${geproxy_ip}:${toString imaged_port}";

  adminBridges = lib.optional adminEnabled adminBridge;
  ifaceSet = ifaces: "{ ${lib.concatMapStringsSep ", " (iface: ''"${iface}"'') ifaces} }";
  lanIfaces = ifaceSet ([ contestBridge ] ++ adminBridges);
  mgmtIfaces = ifaceSet (adminBridges ++ [ cfg.uplink ]);
  webIfaces = ifaceSet (adminBridges ++ [ cfg.uplink contestBridge ]);
  cdsIfaces = ifaceSet (adminBridges ++ [ contestBridge ]);
  adminRules = rules: lib.optionalString adminEnabled (lib.concatStringsSep "\n    " rules);

  proxiedHosts = ip: [
    "/judge.gehack.nl/${ip}"
    "/imaged.gehack.nl/${ip}"
    "/loom.gehack.nl/${ip}"
    "/cds.gehack.nl/${ip}"
    "/cds/${ip}"
    "/docs.gehack.nl/${ip}"
  ];

  dnsmasqFormat = pkgs.formats.keyValue {
    mkKeyValue = name: value: if value == true then name else "${name}=${toString value}";
    listsAsDuplicateKeys = true;
  };

  adminDnsmasqConf = dnsmasqFormat.generate "dnsmasq-admin.conf" {
    log-queries = true;
    log-dhcp = true;

    domain-needed = true;
    bogus-priv = true;

    bind-interfaces = true;
    interface = adminBridge;
    except-interface = "lo";
    dhcp-authoritative = true;
    listen-address = admin_ip;
    resolv-file = uplinkResolvConf;
    dhcp-leasefile = "/var/lib/dnsmasq-admin/dnsmasq.leases";

    dhcp-range = "${adminBridge},10.0.1.50,10.0.1.250,255.255.255.0,infinite";
    dhcp-option = [
      "${adminBridge},3,${admin_ip}"
      "${adminBridge},6,${admin_ip}"
      "${adminBridge},42,${admin_ip}"
    ];
    address = proxiedHosts admin_ip;
    server = [ "/team.loom/127.0.0.1#5053" ];
  };
in
{
  options.geproxy.network = {
    uplink = lib.mkOption {
      type = lib.types.str;
      default = "wlp6s0";
      example = "wlp0s20f3";
      description = "Interface carrying upstream internet access; it is the only interface NAT masquerades to.";
    };

    contestInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "eno3"
        "eno4"
        "eno5"
        "eno6"
      ];
      example = [ "enp0s31f6" ];
      description = "Physical ports enslaved to the contest bridge.";
    };

    admin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Serve the organiser network on a second bridge with its own dnsmasq,
          resolver and Traefik entryPoint. Disable on hardware with a single
          ethernet port, which then carries the contest network only.
        '';
      };

      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "eno1"
          "eno2"
        ];
        description = "Physical ports enslaved to the admin bridge.";
      };
    };
  };

  config = {
    networking = {
      hostName = "geproxy";
      useDHCP = false;
      wireless = {
        enable = true;
        networks."iotroam".psk = "gehackgehack";
      };
      bridges = {
        ${contestBridge}.interfaces = cfg.contestInterfaces;
      }
      // lib.optionalAttrs adminEnabled {
        ${adminBridge}.interfaces = cfg.admin.interfaces;
      };
      interfaces = {
        ${cfg.uplink}.useDHCP = true;
        ${contestBridge} = {
          useDHCP = false;
          ipv4 = {
            addresses = [
              {
                address = geproxy_ip;
                prefixLength = 24;
              }
            ];
          };
        };
      }
      // lib.optionalAttrs adminEnabled {
        ${adminBridge} = {
          useDHCP = false;
          ipv4 = {
            addresses = [
              {
                address = admin_ip;
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
        ruleset = ''
          flush ruleset

          table inet filter {
            chain input {
              type filter hook input priority 0; policy drop;

              iif lo accept
              ct state established,related accept
              ct state invalid drop

              ip protocol icmp accept
              ip6 nexthdr icmpv6 accept

              iifname ${lanIfaces} udp dport { 67, 68 } accept

              udp dport 123 accept

              ${adminRules [
                ''iifname "${adminBridge}" udp dport 53 accept''
                ''iifname "${adminBridge}" tcp dport 53 accept''
              ]}

              iifname "${contestBridge}" ip daddr ${geproxy_ip} udp dport 53 accept
              iifname "${contestBridge}" ip daddr ${geproxy_ip} tcp dport 53 accept

              iifname ${lanIfaces} udp dport 5353 accept

              iifname "${contestBridge}" ip daddr ${geproxy_ip} tcp dport 631 accept

              iifname ${mgmtIfaces} tcp dport 22 accept
              iifname ${webIfaces} tcp dport { 80, 443 } accept
              iifname ${mgmtIfaces} tcp dport 3000 accept
              iifname ${cdsIfaces} tcp dport ${toString cds_port} accept

              iifname "${contestBridge}" udp dport 69 accept
              iifname "${contestBridge}" tcp dport ${toString imaged_port} accept

              iifname "${contestBridge}" udp dport 49152-65535 accept
            }

            chain contest_inet {
            }

            chain forward {
              type filter hook forward priority 0; policy drop;

              ct state established,related accept
              ct state invalid drop

              ${adminRules [
                ''iifname "${adminBridge}" oifname "${cfg.uplink}" accept''
                ''iifname "${adminBridge}" oifname "${contestBridge}" accept''
              ]}

              iifname "${contestBridge}" oifname "${cfg.uplink}" jump contest_inet
            }

            chain output {
              type filter hook output priority 0; policy accept;
              meta skuid ${toString dnsmasqId} udp dport 53 jump contest_inet
              meta skuid ${toString dnsmasqId} tcp dport 53 jump contest_inet
              meta skuid ${toString dnsmasqId} udp dport 53 drop
              meta skuid ${toString dnsmasqId} tcp dport 53 drop
            }
          }

          table ip nat {
            chain postrouting {
              type nat hook postrouting priority 100; policy accept;

              ${adminRules [
                ''iifname "${adminBridge}" oifname "${cfg.uplink}" ip saddr ${admin_subnet} masquerade''
              ]}
              iifname "${contestBridge}" oifname "${cfg.uplink}" ip saddr ${contest_subnet} masquerade
            }
          }
        '';
      };
    };

    users.users.dnsmasq = {
      isSystemUser = true;
      group = "dnsmasq";
      uid = dnsmasqId;
    };
    users.groups.dnsmasq = {
      gid = dnsmasqId;
    };
    users.users.dnsmasq-admin = lib.mkIf adminEnabled {
      isSystemUser = true;
      group = "dnsmasq-admin";
      uid = dnsmasqAdminId;
    };
    users.groups.dnsmasq-admin = lib.mkIf adminEnabled {
      gid = dnsmasqAdminId;
    };

    services = {
      dnsmasq = {
        resolveLocalQueries = false;
        enable = true;
        settings = {
          log-queries = true;
          log-dhcp = true;

          domain-needed = true;
          bogus-priv = true;

          bind-interfaces = true;
          interface = contestBridge;
          except-interface = cfg.uplink;
          enable-tftp = true;
          tftp-root = "${pkgs.ipxe}";
          dhcp-authoritative = true;
          listen-address = geproxy_ip;
          resolv-file = uplinkResolvConf;
          local = "/contest.local/";
          domain = [
            "contest.local,${contestBridge}"
          ];
          dhcp-range = [
            "${contestBridge},10.0.0.50,10.0.0.250,255.255.255.0,infinite"
          ];
          dhcp-option = [
            "${contestBridge},3,${geproxy_ip}"
            "${contestBridge},6,${geproxy_ip}"
            "${contestBridge},42,${geproxy_ip}"
          ];
          address = proxiedHosts geproxy_ip;
          dhcp-userclass = "set:ipxe,iPXE";
          dhcp-match = [
            "set:bios,60,PXEClient:Arch:00000"
            "set:efi32,60,PXEClient:Arch:00006"
            "set:efibc,60,PXEClient:Arch:00007"
            "set:efi64,60,PXEClient:Arch:00009"
          ];
          dhcp-boot = [
            "tag:!ipxe,tag:bios,undionly.kpxe,,${geproxy_ip}"
            "tag:!ipxe,tag:efi32,ipxe.efi,,${geproxy_ip}"
            "tag:!ipxe,tag:efibc,ipxe.efi,,${geproxy_ip}"
            "tag:!ipxe,tag:efi64,ipxe.efi,,${geproxy_ip}"
            "tag:ipxe,${imagedUrl}/boot/boot.ipxe"
          ];

          dhcp-host = [
            "b0:0c:d1:de:f0:0d,10.0.0.10,infinite"
            "02:20:d7:6f:20:cc,10.0.0.11,infinite"
          ];
        };
      };
      dnsmasq.settings.server = [ "/team.loom/127.0.0.1#5053" ];

      resolved = {
        enable = true;
        settings.Resolve = {
          MulticastDNS = "resolve";
          LLMNR = false;
        };
      };

      https-dns-proxy = {
        enable = true;
        address = "127.0.0.1";
        port = 5053;
        extraArgs = [
          "-r"
          "https://loom.gehack.nl/api/dns-query"
          "-b"
          "127.0.0.1"
        ];
      };
    };

    systemd.services.dnsmasq-admin = lib.mkIf adminEnabled {
      description = "Dnsmasq Daemon — admin network";
      after = [
        "network.target"
        "systemd-resolved.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq -k --conf-file=${adminDnsmasqConf}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        User = "dnsmasq-admin";
        Group = "dnsmasq-admin";
        StateDirectory = "dnsmasq-admin";
        AmbientCapabilities = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
          "CAP_NET_ADMIN"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
          "CAP_NET_ADMIN"
        ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        Restart = "on-failure";
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
  };
}
