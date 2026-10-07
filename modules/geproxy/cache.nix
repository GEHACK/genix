{
  lib,
  config,
  ...
}:
let
  port = 5000;
in
{
  options.geproxy.cache.enable = lib.mkEnableOption "an unsigned harmonia binary cache of geproxy's store, reachable as `cache`";

  config = lib.mkIf config.geproxy.cache.enable {
    services.harmonia.cache = {
      enable = true;
      settings = {
        bind = "[::]:${toString port}";
        enable_compression = true;
        workers = 8;
      };
    };

    geproxy.ports.cache.tcp = [ port ];
  };
}
