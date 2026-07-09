{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.teammachine.games.enable = lib.mkEnableOption "downtime games";

  config = lib.mkIf config.teammachine.games.enable {
    home.packages = with pkgs; [
      ninvaders
      nsnake
      moon-buggy
      bsdgames
      aisleriot
      gnome-mines
      gnome-mahjongg
      gnome-sudoku
      quadrapassel
      gnome-2048
      five-or-more
      four-in-a-row
      sgt-puzzles
      supertux
      supertuxkart
      neverball
    ];

    dconf.settings = {
      "org/gnome/desktop/app-folders" = {
        folder-children = [ "Games" ];
      };
      "org/gnome/desktop/app-folders/folders/Games" = {
        name = "Games";
        categories = [ "Game" ];
      };
    };
  };
}
