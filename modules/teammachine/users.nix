{ lib, config, ... }:
{
  users.users.team = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets.hashed-password.path;
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
  };

  # Disable su for contest user
  environment.etc."su-denied-users".text = ''
    team
  '';

  security.pam.services.su.text = lib.mkBefore ''
    auth requisite pam_listfile.so item=ruser sense=deny file=/etc/su-denied-users onerr=succeed
  '';

}
