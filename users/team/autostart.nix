{ pkgs, ... } : {
  xdg.enable = true;
  xdg.autostart.enable = true;
  xdg.autostart.entries = [
    "${pkgs.firefox}/share/applications/firefox.desktop"
  ];
}