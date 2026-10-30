{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Registers every print with the balloons service, which answers with a
  # `print_job_id` the cover template prints as a barcode. Its own `&&` group
  # rather than chained after `info`: cuproxy drops the rest of a chain when a
  # hook fails, and team-info 404s for machines without a seated team. The
  # address must match `listenAddr` in balloons.nix.
  balloonsHook = lib.optionalString config.geproxy.balloons.enable "&&printjob;POST;http://127.0.0.1:8090/api/cuproxy/print-job";
in
{
  options.geproxy.cuproxy = {
    enable = lib.mkEnableOption "the print proxy, reachable as `printing`";
    printerTo = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.10:631/ipp/print";
      example = "ipp.example.org:631/printers/queue";
      description = "IPP host:port/path cuproxy forwards prints to.";
    };
  };

  config = lib.mkIf config.geproxy.cuproxy.enable {
    services.cuproxy = {
      enable = true;
      logLevel = "info";
      listen = "0.0.0.0:631";
      inherit (config.geproxy.cuproxy) printerTo;
      printerTls = false;
      # printerUsername = "<corporate-user>";
      settings = {
        WEBHOOKS_TO_CALL = "info;GET;https://loom.gehack.nl/api/team-info/{{requesting_ip}}&&map;GET;https://loom.gehack.nl/api/map-image?ip={{requesting_ip}}${balloonsHook}";
        TYPST_TEMPLATE = "${./assets/print_template.typ}";
        # Bundled rather than fetched at runtime: if the package download
        # fails, typst fails, and cuproxy prints the job without any cover.
        TYPST_BIN = "${pkgs.typst.withPackages (ps: [ ps.tiaoma_0_3_0 ])}/bin/typst";
      };
    };

    geproxy.ports.printing.tcp = [ 631 ];
  };
}
