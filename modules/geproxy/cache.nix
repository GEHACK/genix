{
  lib,
  config,
  geproxy_ip,
  ...
}:
let
  cfg = config.geproxy.cache;
  port = 5000;
in
{
  options.geproxy.cache = {
    enable = lib.mkEnableOption "an unsigned harmonia binary cache of geproxy's store, reachable as `cache`";

    host = lib.mkOption {
      type = lib.types.str;
      default = geproxy_ip;
      example = "geproxy.local";
      description = "Name or address fanout tells the laptops to fetch the cache from.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.harmonia.cache = {
      enable = true;
      settings = {
        bind = "[::]:${toString port}";
        enable_compression = true;
        workers = 8;
      };
    };

    geproxy.ports.cache.tcp = [ port ];

    services.buildFanout.cacheUrl = "http://${cfg.host}:${toString port}";
  };
}
