{ pkgs, config, ... }:
{

  sops.secrets.hashed-password.neededForUsers = true;

  security.sudo.wheelNeedsPassword = false;
  users = {
    mutableUsers = false;
    users = {
      root.openssh.authorizedKeys.keyFiles = [ ../authorized_keys ];
      gehack = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPasswordFile = config.sops.secrets.hashed-password.path;
        openssh.authorizedKeys.keyFiles = [ ../authorized_keys ];
        shell = pkgs.zsh;
      };
    };
  };

  programs.zsh.enable = true;
}
