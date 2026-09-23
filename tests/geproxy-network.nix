{
  pkgs,
  lib,
  sopsModule,
}:
let
  contestId = "test";
  upstreamIp = "192.168.3.2";
  geproxyUplinkIp = "192.168.3.1";

  secrets =
    pkgs.runCommand "geproxy-network-test-secrets"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.sops
        ];
      }
      ''
        mkdir -p $out
        age-keygen -o $out/key.txt
        echo 'cloudflare-token: unused' > plain.yaml
        sops --encrypt --age "$(age-keygen -y $out/key.txt)" plain.yaml > $out/secrets.yaml
      '';

  staticAddress = iface: address: {
    networking.interfaces.${iface}.ipv4.addresses = lib.mkForce [
      {
        inherit address;
        prefixLength = 24;
      }
    ];
  };

  dhcpClient = {
    virtualisation.vlans = [ 1 ];
    networking = {
      useDHCP = false;
      interfaces.eth1 = {
        useDHCP = true;
        ipv4.addresses = lib.mkForce [ ];
      };
    };
    environment.systemPackages = [
      pkgs.curl
      pkgs.dig
    ];
  };
in
pkgs.testers.runNixOSTest {
  name = "geproxy-network";

  nodes = {
    geproxy = {
      imports = [
        sopsModule
        ../modules/geproxy/network
        (staticAddress "eth3" geproxyUplinkIp)
      ];

      _module.args = {
        contest_id = contestId;
        imaged_port = 8080;
      };

      virtualisation = {
        vlans = [
          1
          2
          3
        ];
        memorySize = 1024;
      };

      environment.etc."geproxy-network-test-key".source = secrets + "/key.txt";
      sops = {
        age.keyFile = "/etc/geproxy-network-test-key";
        defaultSopsFile = secrets + "/secrets.yaml";
      };

      networking = {
        interfaces = {
          eth1.ipv4.addresses = lib.mkForce [ ];
          eth1.ipv6.addresses = lib.mkForce [ ];
          eth2.ipv4.addresses = lib.mkForce [ ];
          eth2.ipv6.addresses = lib.mkForce [ ];
          eth3.useDHCP = lib.mkForce false;
        };
        nameservers = [ upstreamIp ];
      };

      geproxy = {
        uplink.interface = "eth3";

        networks = {
          contest = {
            interfaces = [ "eth1" ];
            address = "10.0.0.1";
            subnet = "10.0.0.0/24";
            internet = "switchable";
            dhcp.range = [
              "10.0.0.50"
              "10.0.0.250"
            ];
          };
          admin = {
            interfaces = [ "eth2" ];
            address = "10.0.1.1";
            subnet = "10.0.1.0/24";
            internet = "always";
            reach = [ "contest" ];
            dhcp.range = [
              "10.0.1.50"
              "10.0.1.250"
            ];
          };
        };

        proxy.sites = {
          judge = {
            upstream = "http://${upstreamIp}";
            rewriteContest = true;
            expose = {
              contest = [ 443 ];
              admin = [ 443 ];
              uplink = [ 443 ];
            };
          };
          cds = {
            upstream = "http://${upstreamIp}";
            expose = {
              admin = [
                443
                8443
              ];
              contest = [ 8443 ];
            };
          };
        };
      };
    };

    contest = dhcpClient;

    admin = {
      imports = [ dhcpClient ];
      virtualisation.vlans = lib.mkForce [ 2 ];
    };

    upstream = {
      imports = [ (staticAddress "eth1" upstreamIp) ];
      virtualisation.vlans = [ 3 ];
      networking.firewall.enable = false;
      environment.systemPackages = [ pkgs.curl ];
      services.nginx = {
        enable = true;
        virtualHosts.default = {
          default = true;
          locations."/".return = "200 'upstream saw $request_uri'";
        };
      };
      services.dnsmasq = {
        enable = true;
        settings.address = "/example.test/${upstreamIp}";
      };
    };
  };

  testScript = ''
    def lease(machine, prefix):
      machine.wait_until_succeeds(f"ip -4 addr show eth1 | grep -q 'inet {prefix}'")
      return machine.succeed("ip -4 -o addr show eth1 | awk '{print $4}' | cut -d/ -f1").strip()

    def status(machine, url, extra=""):
      return machine.succeed(f"curl -sk -o /dev/null -w '%{{http_code}}' --max-time 5 {extra} {url}").strip()

    start_all()
    upstream.wait_for_unit("nginx.service")
    upstream.wait_for_unit("dnsmasq.service")
    geproxy.wait_for_unit("dnsmasq-contest.service")
    geproxy.wait_for_unit("dnsmasq-admin.service")
    geproxy.wait_for_unit("caddy.service")
    geproxy.wait_for_open_port(443)

    contest_ip = lease(contest, "10.0.0.")
    admin_ip = lease(admin, "10.0.1.")

    with subtest("each network resolves proxied hosts to its own geproxy address"):
      assert contest.succeed("dig +short judge.gehack.nl").strip() == "10.0.0.1"
      assert contest.succeed("dig +short cds.gehack.nl").strip() == "10.0.0.1"
      assert admin.succeed("dig +short judge.gehack.nl").strip() == "10.0.1.1"

    with subtest("contest DNS cannot be answered by the admin resolver"):
      contest.fail("dig +time=2 +tries=1 judge.gehack.nl @10.0.1.1")

    with subtest("the contest id is rewritten into the upstream path"):
      body = contest.succeed("curl -sk https://judge.gehack.nl/api/__CONTEST__/x")
      assert "upstream saw /api/${contestId}/x" in body, body

    with subtest("plain http redirects to https"):
      code = status(contest, "http://judge.gehack.nl/")
      assert code in ("301", "302", "308"), code

    with subtest("sites are only served where exposed"):
      assert status(contest, "https://cds.gehack.nl/") == "404"
      assert status(contest, "https://cds.gehack.nl:8443/") == "200"
      assert status(admin, "https://cds.gehack.nl/") == "200"
      assert status(admin, "https://cds.gehack.nl:8443/") == "200"
      uplink = "--resolve judge.gehack.nl:443:${geproxyUplinkIp} --resolve cds.gehack.nl:443:${geproxyUplinkIp}"
      assert status(upstream, "https://judge.gehack.nl/", uplink) == "200"
      assert status(upstream, "https://cds.gehack.nl/", uplink) == "404"
      upstream.fail("curl -sk --max-time 5 --resolve cds.gehack.nl:8443:${geproxyUplinkIp} https://cds.gehack.nl:8443/")

    with subtest("networks reach only what they are allowed to"):
      admin.succeed(f"ping -c1 -W2 {contest_ip}")
      contest.fail(f"ping -c1 -W2 {admin_ip}")
      admin.succeed("curl -s --max-time 5 http://${upstreamIp}")
      assert admin.succeed("dig +short example.test").strip() == "${upstreamIp}"

    with subtest("contest internet is switchable, including upstream DNS"):
      contest.fail("curl -s --max-time 5 http://${upstreamIp}")
      contest.fail("dig +time=2 +tries=1 example.test | grep -q ${upstreamIp}")
      geproxy.succeed("enable-internet")
      contest.succeed("curl -s --max-time 5 http://${upstreamIp}")
      assert contest.succeed("dig +short example.test").strip() == "${upstreamIp}"
      geproxy.succeed("disable-internet contest")
      contest.fail("curl -s --max-time 5 http://${upstreamIp}")
      geproxy.fail("enable-internet admin")

    with subtest("wol finds the leased machines"):
      assert "Sent 2 WOL" in geproxy.succeed("wol")
  '';
}
