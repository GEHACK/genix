{
  lib,
  config,
  dj_url,
  admin_ip,
  ...
}:
let
  cfg = config.geproxy.judge;
  local = cfg.upstream != dj_url;
in
{
  options.geproxy.judge.upstream = lib.mkOption {
    type = lib.types.str;
    default = dj_url;
    example = "https://10.0.1.133";
    description = ''
      DOMjudge behind proxy site `judge`. Anything other than `dj_url` is a DOMjudge
      in geproxy's own networks, so geproxy then resolves the host of every site in front
      of it to itself, and its own clients (balloons, loom) reach that DOMjudge through Caddy.
    '';
  };

  config = {
    geproxy.proxy.sites.judge = {
      inherit (cfg) upstream;
      rewriteContest = true;
    };

    networking.hosts.${admin_ip} = lib.mkIf local (
      lib.mapAttrsToList (_: site: site.host) (
        lib.filterAttrs (_: site: site.upstream == cfg.upstream) config.geproxy.proxy.sites
      )
    );
  };
}
