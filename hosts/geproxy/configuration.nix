{
  lib,
  dj_url,
  geproxy_ip,
  contest_subnet,
  admin_ip,
  admin_subnet,
  ...
}:
let
  atVenue = false;

  everywhere = {
    contest = [ 443 ];
    admin = [ 443 ];
    uplink = [ 443 ];
  };
in
{
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/geproxy
  ];

  geproxy = {
    uplink = {
      interface = "eno1";
      announce = atVenue;
      allow = [
        "ssh"
      ]
      ++ lib.optionals atVenue [
        "imaged"
        "printing"
        "ntp"
        "cache"
      ];
    };

    networks = {
      contest = {
        interfaces = [
          "eno3"
          "eno4"
          "eno5"
          "eno6"
        ];
        address = geproxy_ip;
        subnet = contest_subnet;
        internet = "switchable";
        allow = [
          "ntp"
          "printing"
          "imaged"
          "cache"
        ];
        pxe.enable = true;
        domain = "contest.local";
        dhcp = {
          range = [
            "10.0.0.50"
            "10.0.0.250"
          ];
          reservations = {
            printer = {
              mac = "b0:0c:d1:de:f0:0d";
              ip = "10.0.0.10";
            };
            escpos = {
              mac = "02:20:d7:6f:20:cc";
              ip = "10.0.0.11";
            };
          };
        };
      };

      admin = {
        interfaces = [ "eno2" ];
        address = admin_ip;
        subnet = admin_subnet;
        internet = "always";
        reach = [ "contest" ];
        allow = [
          "ssh"
          "ntp"
          "cache"
        ];
        dhcp.range = [
          "10.0.1.50"
          "10.0.1.250"
        ];
      };
    };

    proxy = {
      authentik = "https://authentik.gewis.nl";
      sites = {
        judge = {
          upstream = dj_url;
          rewriteContest = true;
          expose = everywhere;
        };
        loom = {
          expose = {
            contest = [ 443 ];
            admin = [ 443 ];
          }
          // lib.optionalAttrs atVenue { uplink = [ 443 ]; };
          tunnel = 443;
        };
        docs.expose = everywhere;
        metrics.expose = {
          contest = [ 443 ];
          admin = [ 443 ];
        }
        // lib.optionalAttrs atVenue { uplink = [ 443 ]; };
        grafana = {
          expose.admin = [ 443 ];
          tunnel = 443;
        };
        balloons.expose.admin = [ 443 ];
        cds.expose = {
          admin = [
            443
            8443
          ];
          contest = [ 8443 ];
        };
        imaged = {
          expose.admin = [ 443 ];
          tunnel = 443;
        };
      };
    };

    tunnel.enable = true;

    loomDns.enable = true;
    loom.enable = true;
    monitoring.enable = true;
    ntp.enable = true;
    ddns.enable = true;
    cuproxy.enable = true;
    imaged.enable = true;
    multicastInterface = if atVenue then "eno1" else "br-contest";
    balloons.enable = true;
    devdocs.enable = true;
    cds.enable = true;
    cache = {
      enable = true;
      host = if atVenue then "geproxy.local" else geproxy_ip;
    };
  };

  networking.hostName = "geproxy";

  home-manager.users.gehack.teammachine.neovim.enable = true;

  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth.enable = false;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
