{ lib, ... }:
{
  users.users.team = {
    isNormalUser = true;
    # TODO: encrypt a strong password with sops nix
    initialPassword = "gehackgehack";
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
