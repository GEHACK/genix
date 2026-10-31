{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.teammachine.printer;
in
{
  options.teammachine.printer.enable =
    lib.mkEnableOption "contest CUPS printer";

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = lib.singleton (
        pkgs.linkFarm "drivers" [
          {
            name = "share/cups/model/printer.ppd";
            path = ./assets/printer.ppd;
          }
        ]
      );
    };

    hardware.printers = {
      ensurePrinters = [
        {
          name = "printer";
          deviceUri = "ipp://${config.teammachine.geproxy.host}:631/ipp/print";
          model = "printer.ppd";
          # Send `sides=one-sided` with every job: cuproxy forwards it as is,
          # and the upstream queue duplexes jobs that leave it out.
          ppdOptions = {
            Duplex = "None";
            sides-default = "one-sided";
          };
        }
      ];
      ensureDefaultPrinter = "printer";
    };

    systemd.services.ensure-printers = {
      restartTriggers = [ ./assets/printer.ppd ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 10;
      };
      unitConfig = {
        StartLimitBurst = 10;
        StartLimitIntervalSec = 300;
      };
    };
  };
}
