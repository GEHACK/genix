{
  lib,
  config,
  contest_id,
  ...
}:
let
  inherit (config.geproxy) networks proxy;

  sites = lib.filterAttrs (_: site: site.expose != { } || site.tunnel != null) proxy.sites;
  hosts = lib.unique (lib.mapAttrsToList (_: site: site.host) sites);

  zonesServing =
    port: site: lib.attrNames (lib.filterAttrs (_: ports: lib.elem port ports) site.expose);
  zonesOpen = port: lib.unique (lib.concatMap (zonesServing port) (lib.attrValues sites));
  subnets = zones: map (zone: networks.${zone}.subnet) (lib.remove "uplink" zones);

  guard =
    ranges: denied:
    lib.optionalString (ranges != [ ]) ''
      @denied ${lib.optionalString (!denied) "not "}remote_ip ${toString ranges}
      respond @denied 404
    '';

  access =
    port: site:
    let
      allowed = zonesServing port site;
    in
    if lib.elem "uplink" allowed then
      guard (subnets (lib.subtractLists allowed (zonesOpen port))) true
    else
      guard (subnets allowed ++ lib.optional (site.tunnel == port) "127.0.0.1/32") false;

  loginCheck = ''
    reverse_proxy /outpost.goauthentik.io/* ${proxy.authentik} {
      header_up Host {http.reverse_proxy.upstream.host}
    }
    forward_auth ${proxy.authentik} {
      uri /outpost.goauthentik.io/auth/caddy
      header_up Host {http.reverse_proxy.upstream.host}
    }
    request_header X-Proxy-Authorized true
  '';

  ports =
    site:
    lib.unique (
      lib.concatLists (lib.attrValues site.expose) ++ lib.optional (site.tunnel != null) site.tunnel
    );

  vhost = site: port: {
    name = "${site.host}:${toString port}";
    value = {
      useACMEHost = "gehack";
      extraConfig = ''
        route {
          ${access port site}
          ${lib.optionalString site.rewriteContest "uri path_regexp __CONTEST__ ${contest_id}"}
          ${lib.optionalString site.login "request_header -X-Proxy-Authorized"}
          ${site.extraConfig}
          ${lib.optionalString site.login loginCheck}
          reverse_proxy ${site.upstream} {
            header_up Host {hostport}
            ${lib.optionalString site.insecureUpstream ''
              transport http {
                tls_insecure_skip_verify
              }
            ''}
          }
        }
      '';
    };
  };
in
{
  config = lib.mkIf (sites != { }) {
    sops.secrets.cloudflare-token = { };

    security.acme = {
      acceptTerms = true;
      defaults.email = "gehack@gewis.nl";
      certs.gehack = {
        domain = lib.head hosts;
        extraDomainNames = lib.tail hosts;
        dnsProvider = "cloudflare";
        credentialFiles.CF_DNS_API_TOKEN_FILE = config.sops.secrets.cloudflare-token.path;
      };
    };

    services.caddy = {
      enable = true;
      globalConfig = ''
        grace_period 10s
        servers {
          protocols h1 h2
          timeouts {
            read_body_idle 24h
          }
        }
      '';
      virtualHosts = lib.listToAttrs (
        lib.concatMap (site: map (vhost site) (ports site)) (lib.attrValues sites)
      );
    };
  };
}
