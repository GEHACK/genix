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

  # systemd's own x11.conf only creates /tmp/.X11-unix at boot ("D!"), so its
  # entry is absent from `systemd-tmpfiles --clean` runs: on a long-uptime
  # machine the daily cleaner deletes the (empty, aged) directory, and the next
  # graphical login recreates it owned by that user with mode 0755. Every other
  # user's session then dies, because mutter aborts when /tmp/.X11-unix is owned
  # by neither root nor the session user. Declaring it here without a "!" flag
  # or age keeps it root-owned, excluded from cleaning, and re-normalised on
  # every activation.
  systemd.tmpfiles.rules = [ "d /tmp/.X11-unix 1777 root root -" ];

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
