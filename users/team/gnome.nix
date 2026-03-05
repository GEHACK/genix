_: {
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

