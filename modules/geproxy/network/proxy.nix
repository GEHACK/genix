{
  lib,
  config,
  contest_id,
  ...
}:
let
  inherit (config.geproxy) networks proxy;

  sites = lib.filterAttrs (_: site: site.expose != { }) proxy.sites;
  hosts = lib.unique (lib.mapAttrsToList (_: site: site.host) sites);

  zonesServing =
    port: site: lib.attrNames (lib.filterAttrs (_: ports: lib.elem port ports) site.expose);
  zonesOpen = port: lib.unique (lib.concatMap (zonesServing port) (lib.attrValues sites));
  subnets = zones: map (zone: networks.${zone}.subnet) (lib.remove "uplink" zones);

  guard =
    zones: denied:
    lib.optionalString (zones != [ ]) ''
      @denied ${lib.optionalString (!denied) "not "}remote_ip ${toString (subnets zones)}
      respond @denied 404
    '';

  access =
    port: site:
    let
      allowed = zonesServing port site;
    in
    if lib.elem "uplink" allowed then
      guard (lib.subtractLists allowed (zonesOpen port)) true
    else
      guard allowed false;

  vhost = site: port: {
    name = "${site.host}:${toString port}";
    value = {
      useACMEHost = "gehack";
      extraConfig = ''
        ${access port site}
        ${lib.optionalString site.rewriteContest "uri path_regexp __CONTEST__ ${contest_id}"}
        reverse_proxy ${site.upstream} ${lib.optionalString site.insecureUpstream "{\ntransport http {\ntls_insecure_skip_verify\n}\n}"}
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
        }
      '';
      virtualHosts = lib.listToAttrs (
        lib.concatMap (site: map (vhost site) (lib.unique (lib.concatLists (lib.attrValues site.expose)))) (
          lib.attrValues sites
        )
      );
    };
  };
}
