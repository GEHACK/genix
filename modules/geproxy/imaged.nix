{
  lib,
  config,
  geproxy_ip,
  imaged_port,
  imaged-pkgs,
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
      inherit (config.geproxy) multicastInterface;
      dataDir = "/var/lib/imaged";
      logLevel = "info";
      boot.profiles.x86_64 = {
        arch = "x86_64";
        initrds = [ imaged-pkgs.display-intel ];
      };
    };

    geproxy.ports.imaged = {
      tcp = [ imaged_port ];
      udp = [ "50000-50257" ];
    };
    geproxy.proxy.sites.imaged = {
      upstream = "http://${webAddr}";
      login = true;
    };
  };
}
