{ config, ... }: {
  sops.secrets.cloudflare-token = { };
  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.sops.secrets.cloudflare-token.path;
    domains = [ "geproxy.gehack.nl" ];
    ipv4 = true;
    ipv6 = false;
    proxied = false;
    frequency = "*:0/5";
  };
}
