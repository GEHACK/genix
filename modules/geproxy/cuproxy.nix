{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.geproxy.cuproxy.enable = lib.mkEnableOption "the print proxy, reachable as `printing`";

  config = lib.mkIf config.geproxy.cuproxy.enable {
    services.cuproxy = {
      enable = true;
      logLevel = "info";
      printerTo = "10.0.0.10:631/ipp/print";
      settings = {
        WEBHOOKS_TO_CALL = "info;GET;https://loom.gehack.nl/api/team-info/{{requesting_ip}}&&map;GET;https://loom.gehack.nl/api/map-image?ip={{requesting_ip}}";
        TYPST_TEMPLATE = "${./assets/print_template.typ}";
        TYPST_BIN = "${pkgs.typst}/bin/typst";
      };
    };

    geproxy.ports.printing.tcp = [ 631 ];
  };
}
