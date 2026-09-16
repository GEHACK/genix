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
    gnome-control-center
  ];
  
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;

  # Disable audio output while keeping microphone input
  services.pipewire.wireplumber.extraConfig."50-disable-audio-output" = {
    "monitor.alsa.rules" = [{
      matches = [{ "node.name" = "~alsa_output.*"; }];
      actions.update-props."node.disabled" = true;
    }];
  };

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
