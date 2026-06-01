{ config, lib, balloons-pkg, dj_url, ... }:
let
  # Edit these for your contest.
  contestId = "1";
  escposAddr = "10.0.0.10:9100";
  escposWidth = "576";
  publicHost = "balloons.gehack.nl";
  listenAddr = "127.0.0.1:8090";
in
{
  sops.secrets.balloons-env = {
    owner = "balloons";
    group = "balloons";
    mode = "0400";
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
      DOMJUDGE_CONTEST_ID = contestId;
      PRINTER_KIND = "escpos";
      PRINTER_ESCPOS_ADDR = escposAddr;
      PRINTER_ESCPOS_WIDTH = escposWidth;
      STATE_DB = "/var/lib/balloons/balloons.db";
      CONTEST_TZ = "Europe/Amsterdam";
      SCAN_BASE_URL = "https://${publicHost}";
    };

    serviceConfig = {
      ExecStart = lib.getExe balloons-pkg;
      EnvironmentFile = config.sops.secrets.balloons-env.path;
      User = "balloons";
      Group = "balloons";
      StateDirectory = "balloons";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # DNS: resolve the public host to geproxy on the contest network.
  services.dnsmasq.settings.address = [
    "/${publicHost}/10.0.0.1"
  ];

  # Traefik: route balloons.gehack.nl -> local balloons server.
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
