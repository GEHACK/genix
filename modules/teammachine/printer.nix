{
  config,
  lib,
  pkgs,
  geproxy_ip,
  ...
}:
let
  cfg = config.teammachine.printer;
in
{
  options.teammachine.printer.enable =
    lib.mkEnableOption "contest CUPS printer (PSGEWIS1)";

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = lib.singleton (
        pkgs.linkFarm "drivers" [
          {
            name = "share/cups/model/PSGEWIS1.ppd";
            path = ./assets/PSGEWIS1.ppd;
          }
        ]
      );
    };

    hardware.printers = {
      ensurePrinters = [
        {
          name = "PSGEWIS1";
          deviceUri = "ipp://${geproxy_ip}:631/ipp/print";
          model = "PSGEWIS1.ppd";
        }
      ];
      ensureDefaultPrinter = "PSGEWIS1";
    };

    systemd.services.ensure-printers = {
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
