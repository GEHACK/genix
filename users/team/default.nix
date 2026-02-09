_: {
  imports = [
    ./browser.nix
    ./gnome.nix
    ./vscode.nix
  ];

  home = {
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
