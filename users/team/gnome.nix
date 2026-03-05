{ lib, ... }: 
let
  mkTuple = lib.hm.gvariant.mkTuple;
  
  activeKeyboards = [ 
    "us" 
    "nl"
    # Right now, most are disabled
    # "de"
    # "fr"
    # "be"
    # "es"
    # "it"
    # "pt"
    # "gr"
    # "se"
    # "dk"
    # "fi"
    # "ee"
    # "lv"
    # "lt"
    # "pl"
    # "cz"
    # "sk"
    # "hu"
    # "ro"
    # "bg"
    # "hr"
    # "si"
  ];

  # This automatically wraps each layout in the ["xkb", "layout"] tuple format
  gnomeInputSources = builtins.map (layout: mkTuple [ "xkb" layout ]) activeKeyboards;
in 
{
  xdg.desktopEntries = { 
    "cups" = {
      name = "Manage Printing";
      noDisplay = true;
      exec = "xdg-open http://localhost:631/";
      type = "Application";
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
      "org/gnome/desktop/input-sources" = {
        sources = gnomeInputSources;
      };
    };
  };
}