{
  lib,
  config,
  dj_url,
  admin_ip,
  ...
}:
let
  backendAddr = "127.0.0.1:3010";
in
{
  options.geproxy.loom.enable = lib.mkEnableOption "the loom backend with its dashboard as proxy site `loom`";

  config = lib.mkIf config.geproxy.loom.enable {
    sops.secrets = {
      "loom.authToken".restartUnits = [ "loom-backend.service" ];
      "loom.domjudge.password".restartUnits = [ "loom-backend.service" ];
    };

    services.loom-backend = {
      enable = true;
      listenAddress = backendAddr;
      authTokenFile = config.sops.secrets."loom.authToken".path;
      trustedProxyHeader = true;
      video.multicastInterface = config.geproxy.multicastInterface;
      contestApi = {
        baseUrl = dj_url;
        username = "loom";
        passwordFile = config.sops.secrets."loom.domjudge.password".path;
      };
    };

    networking.hosts.${admin_ip} = [ config.geproxy.proxy.sites.loom.host ];

    geproxy.proxy.sites.loom = {
      upstream = "h2c://${backendAddr}";
      login = true;
      extraConfig = ''
        @station header Content-Type application/grpc
        reverse_proxy @station h2c://${backendAddr}
        reverse_proxy /api/* h2c://${backendAddr}
      '';
    };
  };
}
