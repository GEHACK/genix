{ config, pkgs, ... }: {
  services.xserver.enable = true; #greetd needs this
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = false;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions:${config.services.displayManager.sessionData.desktops}/share/xsessions";
        user = "greeter";
      };
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [ tuigreet ];
}