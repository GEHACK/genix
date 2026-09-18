{
  geproxy_ip,
  imaged_port,
  ...
}:
let
  publicHost = "imaged.gehack.nl";
  machineAddr = "${geproxy_ip}:${toString imaged_port}";
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
    traefik = {
      dynamicConfigOptions = {
        http = {
          routers.imaged = {
            rule = "Host(`${publicHost}`)";
            service = "imaged";
            entryPoints = [ "public" ];
            tls.certResolver = "myresolver";
          };
          services.imaged.loadBalancer.servers = [
            { url = "http://${webAddr}"; }
          ];
        };
      };
    };
  };

  systemd.services.imaged-server.environment = {
    PUBLIC_BASE = machineAddr;
  };
}
