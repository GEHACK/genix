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
      entryPoints.web = {
        address = "0.0.0.0:80";
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
        routers = {
          judge = {
            rule = "Host(`judge.gehack.nl`)";
            service = "judge";
            entryPoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
            };
          };
          loom = {
            rule = "Host(`loom.gehack.nl`)";
            service = "loom";
            entryPoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
            };
          };
          cds = {
            rule = "Host(`cds.gehack.nl`)";
            service = "cds";
            entryPoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
            };
          };
          fog_http = {
            rule = "Host(`fog.gehack.nl`)";
            service = "fog";
            entryPoints = [
              "web"
            ];
          };
          fog = {
            rule = "Host(`fog.gehack.nl`)";
            service = "fog";
            entryPoints = [
              "fog"
              "websecure"
            ];
            tls = {
              certResolver = "myresolver";
            };
          };
        };

        services = {
          judge.loadBalancer.servers = [
            { url = "https://judge.gehack.nl"; }
          ];
          cds.loadBalancer.servers = [
            { url = "https://judge.gehack.nl"; }
          ];
          loom.loadBalancer.servers = [
            { url = "https://loom.gehack.nl"; }
          ];
          fog.loadBalancer.servers = [
            { url = "http://127.0.0.1:3001"; }
          ];
        };
      };
    };
  };
}
