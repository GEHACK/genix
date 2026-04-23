_: {
  imports = [ ./shell.nix ];

  home = {
    stateVersion = "25.11";
  };
  programs.firefox.enable = true;
  programs.home-manager.enable = true;
}
