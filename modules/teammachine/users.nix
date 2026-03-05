{ lib, ... }:
{
  users.users.team = {
    isNormalUser = true;
    # TODO: encrypt a strong password with sops nix
    initialPassword = "gehackgehack";
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
  };

  security.pam.services.su.requireWheel = true;
}
