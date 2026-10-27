_: {
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../fanout_pubkey ];

  home-manager.users.gehack.teammachine = {
    neovim.enable = true;
    firefox.enable = true;
  };
}
