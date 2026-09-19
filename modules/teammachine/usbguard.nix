{
  config,
  lib,
  ...
}:
let
  cfg = config.teammachine.usbguard;
in
{
  options.teammachine.usbguard.enable =
    lib.mkEnableOption "USBGuard device policy enforcement";

  config = lib.mkIf cfg.enable {
    services.usbguard = {
      enable = true;
      presentDevicePolicy = "allow";
      # USB OPTICAL MOUSE (generic Chinese HID chipset, sold under many brands)
      rules = ''
        allow id 275d:0ba6
      '';
    };
  };
}
