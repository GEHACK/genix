{ pkgs, dj_url, ... }:
{
  services = {
    desktopManager.gnome.enable = true;
    gnome = {
      core-apps.enable = false;
      core-developer-tools.enable = false;
      games.enable = false;
    };

    displayManager.gdm.enable = false;
    greetd.loom-greeter = {
      enable = true;
      logLevel = "debug";
      backgroundSource = ../../assets/wallpaper.jpeg;
      url = dj_url;
      username = "team";
      password = "gehackgehack";
    };
  };
  
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
    gnome-control-center
  ];
  
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false; 

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
