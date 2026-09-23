{ lib, config, ... }:
let
  inherit (config.geproxy)
    uplink
    networks
    ports
    proxy
    ;

  set = values: "{ ${lib.concatMapStringsSep ", " toString values} }";
  rules = f: attrs: lib.concatStringsSep "\n    " (lib.concatLists (lib.mapAttrsToList f attrs));

  proxyPorts =
    zone:
    let
      served = lib.unique (lib.concatMap (site: site.expose.${zone} or [ ]) (lib.attrValues proxy.sites));
    in
    lib.optional (lib.elem 443 served) 80 ++ served;

  allowRules =
    iif: zone: allow:
    lib.concatMap (
      service:
      let
        inherit (ports.${service}) tcp udp;
      in
      lib.optional (tcp != [ ]) ''${iif} tcp dport ${set tcp} accept comment "${service}"''
      ++ lib.optional (udp != [ ]) ''${iif} udp dport ${set udp} accept comment "${service}"''
    ) allow
    ++ lib.optional (
      proxyPorts zone != [ ]
    ) ''${iif} tcp dport ${set (proxyPorts zone)} accept comment "proxy"'';

  input =
    name: net:
    let
      iif = ''iifname "${net.bridge}"'';
    in
    [
      ''${iif} udp dport { 67, 68 } accept comment "dhcp"''
      ''${iif} udp dport 5353 accept comment "mdns"''
      ''${iif} ip daddr ${net.address} meta l4proto { tcp, udp } th dport 53 accept comment "dns"''
    ]
    ++ lib.optional net.pxe.enable ''${iif} udp dport { 69, 49152-65535 } accept comment "pxe"''
    ++ allowRules iif name net.allow;

  forward =
    name: net:
    let
      toUplink = ''iifname "${net.bridge}" oifname "${uplink.interface}"'';
    in
    map (peer: ''iifname "${net.bridge}" oifname "${networks.${peer}.bridge}" accept'') net.reach
    ++ lib.optional (net.internet == "always") "${toUplink} accept"
    ++ lib.optional (net.internet == "switchable") "${toUplink} jump ${name}_inet";

  upstreamDns =
    name: net:
    let
      queries = ''meta skuid "dnsmasq-${name}" meta l4proto { tcp, udp } th dport 53'';
    in
    lib.optionals (net.internet != "always") (
      lib.optional (net.internet == "switchable") "${queries} jump ${name}_inet" ++ [ "${queries} drop" ]
    );

  masquerade =
    _: net:
    lib.optional (
      net.internet != "never"
    ) ''iifname "${net.bridge}" oifname "${uplink.interface}" ip saddr ${net.subnet} masquerade'';

  killSwitches = rules (
    name: net: lib.optional (net.internet == "switchable") "chain ${name}_inet { }"
  ) networks;
in
{
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;
    checkRuleset = true;
    preCheckRuleset = ''
      sed -E 's/skuid "dnsmasq-[^"]+"/skuid "nobody"/' -i ruleset.conf
    '';
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

          ${rules input networks}
          ${lib.concatStringsSep "\n    " (
            allowRules ''iifname "${uplink.interface}"'' "uplink" uplink.allow
          )}
        }

        ${killSwitches}

        chain forward {
          type filter hook forward priority 0; policy drop;

          ct state established,related accept
          ct state invalid drop

          ${rules forward networks}
        }

        chain output {
          type filter hook output priority 0; policy accept;

          ${rules upstreamDns networks}
        }
      }

      table ip nat {
        chain postrouting {
          type nat hook postrouting priority 100; policy accept;

          ${rules masquerade networks}
        }
      }
    '';
  };

  geproxy.ports.ssh.tcp = [ 22 ];
}
