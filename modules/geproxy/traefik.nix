{ config, lib, admin_ip, contest_id, ... }:
{
  sops.templates.cloudflare-api-key-env.content = ''
    CF_DNS_API_TOKEN=${config.sops.placeholder.cloudflare-token}
  '';
  services.traefik = {
    enable = true;
    environmentFiles = [ config.sops.templates.cloudflare-api-key-env.path ];

    staticConfigOptions = {
      entryPoints = {
        websecure = {
          address = "0.0.0.0:443";
          http.tls = {
            options = "strictTLS";
            certResolver = "myresolver";
          };
          transport.respondingTimeouts.readTimeout = 0;
        };
        web = {
          address = "0.0.0.0:80";
        };
        public = {
          address = "0.0.0.0:3000";
          http.tls = {
            options = "strictTLS";
            certResolver = "myresolver";
          };
        };
      }
      // lib.optionalAttrs config.geproxy.network.admin.enable {
        admin-net-secure = {
          address = "${admin_ip}:433";
          http.tls = {
            options = "strictTLS";
            certResolver = "myresolver";
          };
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
            middlewares = [ "contest-placeholder" ];
            entryPoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
            };
          };
          devdocs = {
            rule = "Host(`docs.gehack.nl`)";
            service = "docs";
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
        };

        middlewares.contest-placeholder.replacePathRegex = {
          regex = "__CONTEST__";
          replacement = contest_id;
        };

        services = {
          judge.loadBalancer.servers = [
            { url = "https://judge.gehack.nl"; }
          ];
          loom.loadBalancer.servers = [
            { url = "https://loom.gehack.nl"; }
          ];
          docs.loadBalancer.servers = [
            { url = "http://127.0.0.1:3002"; }
          ];
        };
      };
    };
  };
}
