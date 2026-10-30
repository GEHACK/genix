{ lib, ... }:
{
  imports = [ ../../modules/partition ];

  sops.defaultSopsFile = lib.mkForce ../../secrets-judgehost.yaml;
}
