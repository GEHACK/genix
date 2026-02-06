_: {
  imports = [ ./shell.nix ];

  home = {
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
