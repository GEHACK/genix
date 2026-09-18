{
  config,
  lib,
  balloons-pkg,
  dj_url,
  contest_id,
  ...
}:
let
  escposAddr = "10.0.0.11:9100";
  escposWidth = "576";
  # DOMjudge group ids. `system` holds the internal GEHACK team, whose balloons
  # must never reach the printer; `observers` still gets balloons but is skipped
  # when deriving the first solve per problem.
  hideGroupIDs = "system,jury,organization";
  noFirstSolveGroupIDs = "observers";
  publicHost = "balloons.gehack.nl";
  listenAddr = "127.0.0.1:8090";
in
{
  sops.secrets."balloons.domjudge.user" = { };
  sops.secrets."balloons.domjudge.password" = { };

  sops.templates."balloons.env" = {
    owner = "balloons";
    group = "balloons";
    mode = "0400";
    content = ''
      DOMJUDGE_USER=${config.sops.placeholder."balloons.domjudge.user"}
      DOMJUDGE_PASS=${config.sops.placeholder."balloons.domjudge.password"}
    '';
  };

  users.users.balloons = {
    isSystemUser = true;
    group = "balloons";
  };
  users.groups.balloons = { };

  systemd.services.balloons = {
    description = "Balloons — DOMjudge balloon dispatcher";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      ADDR = listenAddr;
      DOMJUDGE_URL = dj_url;
      DOMJUDGE_CONTEST_ID = contest_id;
      HIDE_GROUP_IDS = hideGroupIDs;
      NO_FIRST_SOLVE_GROUP_IDS = noFirstSolveGroupIDs;
      PRINTER_KIND = "escpos";
      PRINTER_ESCPOS_ADDR = escposAddr;
      PRINTER_ESCPOS_WIDTH = escposWidth;
      STATE_DB = "/var/lib/balloons/balloons.db";
      CONTEST_TZ = config.time.timeZone;
      SCAN_BASE_URL = "https://${publicHost}";
      # typst downloads @preview/* packages into XDG_CACHE_HOME at runtime.
      XDG_CACHE_HOME = "/var/cache/balloons";
    };

    serviceConfig = {
      ExecStart = lib.getExe balloons-pkg;
      EnvironmentFile = config.sops.templates."balloons.env".path;
      User = "balloons";
      Group = "balloons";
      StateDirectory = "balloons";
      CacheDirectory = "balloons";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Traefik: route balloons.gehack.nl -> local balloons server.
  # Public DNS (Cloudflare) already points balloons.gehack.nl at geproxy's WAN
  # IP, so we ride the public `websecure` entryPoint like judge/loom/cds/docs.
  services.traefik.dynamicConfigOptions.http.routers.balloons = {
    rule = "Host(`${publicHost}`)";
    service = "balloons";
    entryPoints = [ "websecure" ];
    tls.certResolver = "myresolver";
  };
  services.traefik.dynamicConfigOptions.http.services.balloons.loadBalancer.servers = [
    { url = "http://${listenAddr}"; }
  ];
}
