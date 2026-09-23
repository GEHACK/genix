{ lib, config, ... }:
{
  options.geproxy.ddns.enable = lib.mkEnableOption "publishing the uplink address as geproxy.gehack.nl";

  config = lib.mkIf config.geproxy.ddns.enable {
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
  };
}
