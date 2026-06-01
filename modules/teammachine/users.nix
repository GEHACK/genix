{ lib, config, ... }:
{
  users.users.team = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets.hashed-password.path;
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../fanout_pubkey ];

  security.pam.services.su.requireWheel = true;
}
