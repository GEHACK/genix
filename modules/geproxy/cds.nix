{ config, lib, ... }:
let
  cfg = config.geproxy.cds;
in
{
  options.geproxy.cds.url = lib.mkOption {
    type = lib.types.str;
    default = "https://cds.local:8443";
    example = "https://cds.local:8443";
    description = ''
      Upstream Contest Data Server that `cds.gehack.nl` is proxied to.

      The default is the mDNS name the CDS machine announces on the contest or
      admin bridge, resolved by systemd-resolved on geproxy. The CDS therefore
      needs no DHCP reservation and no rebuild when its address changes; it only
      needs the hostname `cds`.

      Its certificate is not verified, so a self-signed CDS cert is fine.
    '';
  };

  config.services.traefik.dynamicConfigOptions.http = {
    routers.cds = {
      rule = "Host(`cds.gehack.nl`)";
      service = "cds";
      middlewares = [ "contest-placeholder" ];
      entryPoints = [ "websecure" ];
      tls.certResolver = "myresolver";
    };

    services.cds.loadBalancer = {
      servers = [ { url = cfg.url; } ];
      serversTransport = "cds";
    };

    serversTransports.cds.insecureSkipVerify = true;
  };
}
