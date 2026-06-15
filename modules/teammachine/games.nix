{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gehack.teammachine.games;
in
{
  options.gehack.teammachine.games.enable =
    lib.mkEnableOption "downtime games on the teammachine"
    // {
      default = true;
    };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Terminal classics
      ninvaders
      nsnake
      moon-buggy
      bsdgames

      # GNOME games (gnome.games.enable is off, so add individually)
      aisleriot
      gnome-mines
      gnome-mahjongg
      gnome-sudoku
      quadrapassel
      gnome-2048
      five-or-more
      four-in-a-row

      # Puzzle / strategy
      sgt-puzzles

      # Retro arcade
      supertux
      supertuxkart
      neverball
    ];

    # Group every game .desktop entry into a single "Games" folder in the
    # GNOME app grid so the contest tools stay uncluttered.
    home-manager.users.team.dconf.settings = {
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
