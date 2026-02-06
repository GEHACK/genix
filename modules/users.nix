{ pkgs, ... }:
{
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../authorized_keys ];

  security.sudo.wheelNeedsPassword = false;

  users.users.gehack = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # TODO: encrypt a strong password with sops nix
    initialPassword = "gehackgehack";
    openssh.authorizedKeys.keyFiles = [ ../authorized_keys ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
