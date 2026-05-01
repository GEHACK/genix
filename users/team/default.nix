_: {
  imports = [
    ./autostart.nix
    ./browser.nix
    ./gnome.nix
    ./intellij.nix
    ./nix-block.nix
    ./vscode.nix
  ];

  home = {
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
