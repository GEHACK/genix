_: {
  imports = [ 
    ./vscode.nix 
    ./browser.nix 
  ];

  home = {
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
