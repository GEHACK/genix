_: {
  imports = [
    ./autostart.nix
    ./browser.nix
    ./cuproxy.nix
    ./gnome.nix
    ./nix-block.nix
    ./vscode.nix
  ];

  home = {
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
