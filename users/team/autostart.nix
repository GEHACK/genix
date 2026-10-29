{ config, lib, ... } : {
  xdg.enable = true;
  xdg.autostart.enable = true;
  xdg.autostart.entries = lib.mkIf config.teammachine.firefox.enable [
    "${config.programs.firefox.finalPackage}/share/applications/firefox.desktop"
  ];
}
