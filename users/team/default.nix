_: {
  imports = [
    ./autostart.nix
    ./games.nix
    ./gnome.nix
    ./ides.nix
    ./languages.nix
    ./misc-packages.nix
    ./nix-block.nix
    ./submit.nix
    ./vscode.nix
  ];

  home = {
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
