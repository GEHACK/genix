{
  config,
  lib,
  cds_port,
  ...
}:
let
  cfg = config.geproxy.cds;
in
{
  options.geproxy.cds.enable = lib.mkEnableOption "proxying the Contest Data Server as proxy site `cds`";

  options.geproxy.cds.url = lib.mkOption {
    type = lib.types.str;
    default = "https://cds.local:${toString cds_port}";
    example = "https://10.0.1.2:8443";
    description = ''
      Upstream Contest Data Server that `cds.gehack.nl` is proxied to.

      The default is the mDNS name the CDS machine announces on the contest or
      admin bridge, resolved by systemd-resolved on geproxy. The CDS therefore
      needs no DHCP reservation and no rebuild when its address changes; it only
      needs the hostname `cds`.

      Its certificate is not verified, so a self-signed CDS cert is fine.
    '';
  };

  config.geproxy.proxy.sites.cds = lib.mkIf cfg.enable {
    upstream = cfg.url;
    rewriteContest = true;
    insecureUpstream = true;
  };
}
