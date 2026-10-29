{
  pkgs,
  lib,
  config,
  imaged_port,
  ...
}:
let
  inherit (config.geproxy)
    uplink
    networks
    dns
    proxy
    ;

  format = pkgs.formats.keyValue {
    mkKeyValue = name: value: if value == true then name else "${name}=${toString value}";
    listsAsDuplicateKeys = true;
  };

  pxeSettings = net: {
    enable-tftp = true;
    tftp-root = "${pkgs.ipxe}";
    dhcp-userclass = "set:ipxe,iPXE";
    dhcp-match = [
      "set:bios,60,PXEClient:Arch:00000"
      "set:efi32,60,PXEClient:Arch:00006"
      "set:efibc,60,PXEClient:Arch:00007"
      "set:efi64,60,PXEClient:Arch:00009"
    ];
    dhcp-boot = [
      "tag:!ipxe,tag:bios,undionly.kpxe,,${net.address}"
      "tag:!ipxe,tag:efi32,ipxe.efi,,${net.address}"
      "tag:!ipxe,tag:efibc,ipxe.efi,,${net.address}"
      "tag:!ipxe,tag:efi64,ipxe.efi,,${net.address}"
      "tag:ipxe,http://${net.address}:${toString imaged_port}/boot/boot.ipxe"
    ];
  };

  domainSettings = net: {
    local = "/${net.domain}/";
    domain = "${net.domain},${net.bridge}";
  };

  settings =
    name: net:
    {
      domain-needed = true;
      bogus-priv = true;

      bind-interfaces = true;
      interface = net.bridge;
      except-interface = "lo";
      listen-address = net.address;
      resolv-file = "/run/systemd/resolve/resolv.conf";

      dhcp-authoritative = true;
      dhcp-ignore-clid = true;
      dhcp-leasefile = "/var/lib/dnsmasq-${name}/dnsmasq.leases";
      dhcp-range = lib.concatStringsSep "," ([ net.bridge ] ++ net.dhcp.range ++ [ "infinite" ]);
      dhcp-option = map (option: "${net.bridge},${toString option},${net.address}") (
        [
          3
          6
        ]
        ++ lib.optional (lib.elem "ntp" net.allow) 42
      );
      dhcp-host = lib.mapAttrsToList (_: host: "${host.mac},${host.ip},infinite") net.dhcp.reservations;

      address = lib.mapAttrsToList (_: site: "/${site.host}/${net.address}") (
        lib.filterAttrs (_: site: site.expose ? ${name}) proxy.sites
      );
      server = lib.mapAttrsToList (domain: server: "/${domain}/${server}") dns.forward;
    }
    // lib.optionalAttrs net.pxe.enable (pxeSettings net)
    // lib.optionalAttrs (net.domain != null) (domainSettings net);

  uplinkSettings = {
    bind-dynamic = true;
    interface = uplink.interface;
    except-interface = "lo";
    no-resolv = true;
    no-hosts = true;
    interface-name = lib.mapAttrsToList (_: site: "${site.host},${uplink.interface}/4") (
      lib.filterAttrs (_: site: site.expose ? uplink) proxy.sites
    );
  };

  instances =
    lib.mapAttrs (name: net: {
      description = "the ${name} network";
      settings = settings name net;
    }) networks
    // lib.optionalAttrs uplink.announce {
      uplink = {
        description = "the uplink";
        settings = uplinkSettings;
      };
    };

  capabilities = [
    "CAP_NET_BIND_SERVICE"
    "CAP_NET_RAW"
    "CAP_NET_ADMIN"
  ];
in
{
  users.users = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "dnsmasq-${name}" {
      isSystemUser = true;
      group = "dnsmasq-${name}";
    }
  ) instances;

  users.groups = lib.mapAttrs' (name: _: lib.nameValuePair "dnsmasq-${name}" { }) instances;

  systemd.services = lib.mapAttrs' (
    name: instance:
    let
      conf = format.generate "dnsmasq-${name}.conf" instance.settings;
    in
    lib.nameValuePair "dnsmasq-${name}" {
      description = "Dnsmasq for ${instance.description}";
      after = [
        "network.target"
        "systemd-resolved.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.dnsmasq}/bin/dnsmasq --test --conf-file=${conf}";
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq -k --conf-file=${conf}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        User = "dnsmasq-${name}";
        Group = "dnsmasq-${name}";
        StateDirectory = "dnsmasq-${name}";
        AmbientCapabilities = capabilities;
        CapabilityBoundingSet = capabilities;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        Restart = "on-failure";
      };
    }
  ) instances;

  geproxy = lib.mkIf uplink.announce {
    ports = {
      mdns.udp = [ 5353 ];
      dns = {
        tcp = [ 53 ];
        udp = [ 53 ];
      };
    };
    uplink.allow = [
      "mdns"
      "dns"
    ];
  };
}
