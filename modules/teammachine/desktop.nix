{ pkgs, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    gnome = {
      core-apps.enable = false;
      core-developer-tools.enable = false;
      games.enable = false;
    };

    displayManager.gdm.enable = false;
    greetd.contest-greeter = {
      enable = true;
      logLevel = "debug";
      backgroundSource = ../../assets/wallpaper.jpeg;
    };
  };
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];
  security.pam.services.greetd.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [
    gnome-terminal
    nautilus
  ];
  systemd = {
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
