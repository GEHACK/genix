{
  lib,
  config,
  geproxy_ip,
  imaged_port,
  ...
}:
let
  machineAddr = "${geproxy_ip}:${toString imaged_port}";
  webAddr = "127.0.0.1:8081";
in
{
  options.geproxy.imaged.enable = lib.mkEnableOption "the imaged server, reachable as `imaged`, with its web UI as proxy site `imaged`";

  config = lib.mkIf config.geproxy.imaged.enable {
    services.imaged.server = {
      enable = true;
      bindAddress = "0.0.0.0:${toString imaged_port}";
      publicUrl = "http://${machineAddr}";
      webBindAddress = webAddr;
      multicastInterface = "br-contest";
      dataDir = "/var/lib/imaged";
      logLevel = "info";
    };

    geproxy.ports.imaged = {
      tcp = [ imaged_port ];
      udp = [ "50000-50127" ];
    };
    geproxy.proxy.sites.imaged = {
      upstream = "http://${webAddr}";
      login = true;
    };
  };
}
