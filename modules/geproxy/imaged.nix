_:
let
  publicHost = "imaged.gehack.nl";
  contestAddress = "10.0.0.1";
  serverPort = 8080;
  machineAddr = "${contestAddress}:${toString serverPort}";
  webAddr = "127.0.0.1:8081";
in
{
  services = {
    imaged.server = {
      enable = true;
      bindAddress = machineAddr;
      webBindAddress = webAddr;
      multicastInterface = "br-contest";
      dataDir = "/var/lib/imaged";
      logLevel = "info";
    };

    traefik.dynamicConfigOptions.http.routers.imaged = {
      rule = "Host(`${publicHost}`)";
      service = "imaged";
      entryPoints = [ "public" ];
      tls.certResolver = "myresolver";
    };
    traefik.dynamicConfigOptions.http.services.imaged.loadBalancer.servers = [
      { url = "http://${webAddr}"; }
    ];
  };

  systemd.services.imaged-server.environment = {
    PUBLIC_BASE = machineAddr;
  };
}
