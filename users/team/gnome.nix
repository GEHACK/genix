{ pkgs, ...}: {

  dconf = {
    enable = true;
    settings = {
        "org/gnome/desktop/background" = {
        picture-uri = "file://${./assets/background.png}";
        picture-uri-dark = "file://${./assets/background.png}";
        };
    };
  };  
}