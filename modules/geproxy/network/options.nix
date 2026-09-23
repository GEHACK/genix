{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;

  portsOption = mkOption {
    type = types.listOf (types.either types.port types.str);
    default = [ ];
    example = [
      631
      "49152-65535"
    ];
  };

  network =
    { name, ... }:
    {
      options = {
        bridge = mkOption {
          type = types.str;
          default = "br-${name}";
          description = "Bridge enslaving the physical ports of this network.";
        };

        interfaces = mkOption {
          type = types.listOf types.str;
          description = "Physical ports enslaved to the bridge.";
        };

        address = mkOption {
          type = types.str;
          example = "10.0.0.1";
          description = "Address of geproxy on this network; gateway, resolver and proxy target for its clients.";
        };

        subnet = mkOption {
          type = types.str;
          example = "10.0.0.0/24";
        };

        internet = mkOption {
          type = types.enum [
            "always"
            "never"
            "switchable"
          ];
          default = "never";
          description = ''
            Whether clients reach the uplink. `switchable` starts disabled and is
            toggled at runtime with `enable-internet` / `disable-internet`; it
            also gates the upstream DNS of this network's resolver.
          '';
        };

        reach = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "contest" ];
          description = "Networks whose clients this network may open connections to.";
        };

        allow = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "ssh"
            "ntp"
          ];
          description = "Entries of `geproxy.ports` reachable on geproxy from this network.";
        };

        domain = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "contest.local";
          description = "Local domain answered from DHCP leases.";
        };

        pxe.enable = mkEnableOption "PXE boot into imaged";

        dhcp = {
          range = mkOption {
            type = types.listOf types.str;
            example = [
              "10.0.0.50"
              "10.0.0.250"
            ];
            description = "First and last address handed out, both leased forever.";
          };

          reservations = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  mac = mkOption { type = types.str; };
                  ip = mkOption { type = types.str; };
                };
              }
            );
            default = { };
          };
        };
      };
    };

  site =
    { name, ... }:
    {
      options = {
        host = mkOption {
          type = types.str;
          default = "${name}.gehack.nl";
        };

        upstream = mkOption {
          type = types.str;
          example = "http://127.0.0.1:8090";
        };

        rewriteContest = mkEnableOption "replacing `__CONTEST__` in the request path with the contest id";

        insecureUpstream = mkEnableOption "skipping TLS verification of the upstream";

        expose = mkOption {
          type = types.attrsOf (types.listOf types.port);
          default = { };
          example = {
            admin = [
              443
              8443
            ];
            contest = [ 8443 ];
            uplink = [ 443 ];
          };
          description = ''
            Ports this site is served on, per network name or `uplink`. Clients of
            a network not listed are refused, even on a port another site opens.
          '';
        };
      };
    };
in
{
  options.geproxy = {
    uplink = {
      interface = mkOption {
        type = types.str;
        example = "wlp6s0";
        description = "Interface carrying upstream internet access; the only one NAT masquerades to.";
      };

      allow = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "ssh" ];
        description = "Entries of `geproxy.ports` reachable on geproxy from the uplink.";
      };
    };

    networks = mkOption {
      type = types.attrsOf (types.submodule network);
      default = { };
    };

    ports = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            tcp = portsOption;
            udp = portsOption;
          };
        }
      );
      default = { };
      description = "Named services a network can `allow`.";
    };

    dns.forward = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        "team.loom" = "127.0.0.1#5053";
      };
      description = "Domains every network resolver forwards to a specific server.";
    };

    proxy.sites = mkOption {
      type = types.attrsOf (types.submodule site);
      default = { };
    };
  };
}
