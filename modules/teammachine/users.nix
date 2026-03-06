{ lib, config, ... }:
{
  users.users.team = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets.hashed-password.path;
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
  };

  security.pam.services.su.requireWheel = true;
}
