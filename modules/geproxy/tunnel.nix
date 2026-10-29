{ lib, config, ... }:
let
  tunnelled = lib.filterAttrs (_: site: site.tunnel != null) config.geproxy.proxy.sites;
in
{
  options.geproxy.tunnel.enable = lib.mkEnableOption "publishing proxy sites with `tunnel` through the tunnelrs server";

  config = lib.mkIf config.geproxy.tunnel.enable {
    sops.secrets."tunnelrs.key".restartUnits = [ "tunnelrs-connector.service" ];

    services.tunnelrs.connector = {
      enable = true;
      keyFile = config.sops.secrets."tunnelrs.key".path;
      server = {
        id = "5387b0ee57707157ac4b3107c339e88659913bc2cb32b90dd6f0a0bf9d764d62";
        relays = [ "https://relay.luukblankenstijn.nl:8443" ];
      };
      exposures = lib.mapAttrs' (
        _: site:
        lib.nameValuePair site.host {
          backend = "127.0.0.1:${toString site.tunnel}";
          tls = "passthrough";
        }
      ) tunnelled;
    };
  };
}
