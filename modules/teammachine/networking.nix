{
  config,
  lib,
  pkgs,
  geproxy_ip,
  admin_subnet,
  imaged_port,
  ...
}:
let
  inherit (config.teammachine.geproxy) discover host;

  geproxy = if discover then "@geproxy" else geproxy_ip;
  set = ports: "{ ${lib.concatMapStringsSep ", " toString ports} }";

  rdp = config.teammachine.remoteDesktop or { enable = false; };
  greeter = config.services.greetd.loom-greeter or { enable = false; };
  streams = lib.attrByPath [ "home-manager" "users" "team" "teammachine" "streams" ] null config;

  toGeproxy = {
    tcp = [
      53
      80
      443
      631
      5000
      imaged_port
    ];
    udp = [
      53
      123
    ];
  };

  fromTrusted = [
    22
  ]
  ++ lib.optional rdp.enable rdp.port
  ++ lib.optional (streams != null && streams.enable) streams.port;
in
{

  environment.systemPackages = with pkgs; [
    wakeonlan
  ];

  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts = lib.optionalString (!discover) ''
      ${geproxy_ip} judge
    '';

    interfaces.enp0s31f6.wakeOnLan.enable = true;

    # Disable the default iptables-based firewall manager
    firewall.enable = false;

    nftables = {
      enable = true;
      checkRuleset = true;
      ruleset = ''
        flush ruleset
        table inet filter {
            ${lib.optionalString discover "set geproxy { type ipv4_addr; }"}

            chain input {
                type filter hook input priority filter; policy drop;
                iifname "lo" accept
                ct state established,related accept
                ct state invalid drop
                meta l4proto { icmp, ipv6-icmp } accept
                udp sport 67 udp dport 68 accept comment "dhcp"
                udp dport 5353 accept comment "mdns"
                ip saddr ${geproxy} tcp dport ${set fromTrusted} accept
                ip saddr ${admin_subnet} tcp dport ${set fromTrusted} accept
                ${lib.optionalString greeter.enable "ip saddr ${geproxy} udp dport ${toString greeter.videoStreamPort} accept comment \"loom video\""}
                ip protocol igmp accept
            }

            chain forward {
                type filter hook forward priority filter; policy drop;
            }

            chain output {
                type filter hook output priority filter; policy drop;
                oifname "lo" accept
                ct state established,related accept
                meta l4proto { icmp, ipv6-icmp } accept
                ip protocol igmp accept
                udp sport 68 udp dport 67 accept comment "dhcp"
                ip daddr 224.0.0.251 udp dport 5353 accept comment "mdns"
                ip daddr ${geproxy} tcp dport ${set toGeproxy.tcp} accept
                ip daddr ${geproxy} udp dport ${set toGeproxy.udp} accept
            }
        }
      '';
    };
  };

  services.timesyncd = {
    enable = lib.mkForce true;
    servers = [ host ];
  };

  boot.blacklistedKernelModules = [
    "iwlwifi"
    "btusb"
  ];

  # Prevent non-root users from managing network connections via GNOME
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
          subject.user !== "root") {
        return polkit.Result.NO;
      }
    });
  '';
}
