{ pkgs, ... }:
{
  services.cuproxy = {
    enable = true;
    logLevel = "info";
    printerTo = "10.0.0.10:631/ipp/print";
    settings = {
      WEBHOOKS_TO_CALL = "info;GET;https://loom.gehack.nl/team-info/{{requesting_ip}}&&map;GET;https://loom.gehack.nl/map-image?ip={{requesting_ip}}";
      TYPST_TEMPLATE = "${./assets/print_template.typ}";
      TYPST_BIN = "${pkgs.typst}/bin/typst";
    };
  };
}
