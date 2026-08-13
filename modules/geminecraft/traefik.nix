{ config, ... }:
{
  sops.secrets.cloudflare-api-key-env = { };
  services.traefik = {
    enable = true;
    environmentFiles = [ config.sops.secrets.cloudflare-api-key-env.path ];

    staticConfigOptions = {
      entryPoints.public = {
        address = "0.0.0.0:3000";
        http.tls = {
          options = "strictTLS";
          certResolver = "myresolver";
        };
      };
      certificatesResolvers.myresolver.acme = {
        email = "gehack@gewis.nl";
        dnsChallenge.provider = "cloudflare";
        storage = "/var/lib/traefik/acme.json";
      };
    };

    dynamicConfigOptions.tls.options.strictTLS.sniStrict = true;
  };
}
