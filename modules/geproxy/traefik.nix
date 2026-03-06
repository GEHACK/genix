{ config, ... }:
{
  sops.secrets.cloudflare-api-key-env = { };
  services.traefik = {
    enable = true;
    environmentFiles = [ config.sops.secrets.cloudflare-api-key-env.path ];

    staticConfigOptions = {
      entryPoints.websecure = {
        address = ":443";
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

    dynamicConfigOptions = {
      tls.options.strictTLS.sniStrict = true;

      http = {
        routers.judge = {
          rule = "Host(`judge.gehack.nl`)";
          service = "judge";
          entryPoints = [ "websecure" ];
          tls = {
            certResolver = "myresolver";
          };
        };

        services.judge.loadBalancer.servers = [
          { url = "https://judge.gehack.nl"; }
        ];
      };
    };
  };
}
