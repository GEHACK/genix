{
  pkgs,
  ...
}:
{
  services = {
    desktopManager.gnome.enable = true;
    gnome = {
      core-apps.enable = false;
      core-developer-tools.enable = false;
      games.enable = false;
    };

    displayManager.gdm.enable = false;
  };
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];
  security.pam.services.greetd.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [
    file-roller
    gnome-terminal
    gnome-calculator
    papers
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
