_: {

  xdg.desktopEntries = {
    # The key here must match the exact filename of the system's .desktop file (without the .desktop extension)
    "nvidia-settings" = {
      name = "NVIDIA X Server Settings";
      exec = "nvidia-settings";
      noDisplay = true; # This is the magic line that hides it from the app grid
    };
  };

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/background" = {
        picture-uri = "file://${../../assets/wallpaper.jpeg}";
        picture-uri-dark = "file://${../../assets/wallpaper.jpeg}";
      };
      "org/gnome/shell" = {
        favorite-apps = ["firefox.desktop"];
      };
    };
  };
}

