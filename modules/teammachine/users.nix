{ pkgs, ... }:
{
  users.users.team = {
    isNormalUser = true;
    # TODO: encrypt a strong password with sops nix
    initialPassword = "gehackgehack";
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
