{ config, ... }:
{
  sops.secrets.cloudflare-api-key-env = { };
  services.traefik = {
    enable = true;
    environmentFiles = [ config.sops.secrets.cloudflare-api-key-env.path ];

    staticConfigOptions = {
      entryPoints.websecure = {
        address = "0.0.0.0:443";
        http.tls = {
          options = "strictTLS";
          certResolver = "myresolver";
        };
        transport.respondingTimeouts.readTimeout = 0;
      };
      entryPoints.fog = {
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

        routers.loom = {
          rule = "Host(`loom.gehack.nl`)";
          service = "loom";
          entryPoints = [ "websecure" ];
          tls = {
            certResolver = "myresolver";
          };
        };

        services.judge.loadBalancer.servers = [
          { url = "https://judge.gehack.nl"; }
        ];

        services.loom.loadBalancer.servers = [
          { url = "https://loom.gehack.nl"; }
        ];

        routers.fog = {
          rule = "Host(`fog.gehack.nl`)";
          service = "fog";
          entryPoints = [ "fog" "websecure" ];
          tls = {
            certResolver = "myresolver";
          };
        };

        services.fog.loadBalancer.servers = [
          { url = "http://127.0.0.1:3001"; }
        ];
      };
    };
  };
}
