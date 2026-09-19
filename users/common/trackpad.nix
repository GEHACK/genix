{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.teammachine.trackpad;

  toggle = pkgs.writeShellApplication {
    name = "toggle-trackpad";
    runtimeInputs = [ pkgs.glib ];
    text = ''
      schema=org.gnome.desktop.peripherals.touchpad
      if [ "$(gsettings get $schema send-events)" = "'disabled'" ]; then
        gsettings set $schema send-events enabled
      else
        gsettings set $schema send-events disabled
      fi
    '';
  };

  keybindingPath = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";
  mkKeybinding = binding: {
    inherit binding;
    name = "Toggle trackpad";
    command = lib.getExe toggle;
  };
in
{
  options.teammachine.trackpad = {
    enable = lib.mkEnableOption "trackpad toggle keybinding and launcher entry";

    binding = lib.mkOption {
      type = lib.types.str;
      default = "<Super>t";
      description = "GNOME accelerator that toggles the trackpad.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ toggle ];

    xdg.desktopEntries.toggle-trackpad = {
      name = "Toggle Trackpad";
      comment = "Turn the trackpad off while typing, and back on again";
      exec = lib.getExe toggle;
      icon = "input-touchpad";
      terminal = false;
      type = "Application";
      categories = [
        "Settings"
        "HardwareSettings"
      ];
    };

    dconf.settings = {
      "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
        "/${keybindingPath}/custom0/"
        "/${keybindingPath}/custom1/"
      ];
      "${keybindingPath}/custom0" = mkKeybinding cfg.binding;
      "${keybindingPath}/custom1" = mkKeybinding "XF86TouchpadToggle";
    };
  };
}
