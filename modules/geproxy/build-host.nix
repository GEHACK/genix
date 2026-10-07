_:
let
  inherit ((import ../../flake.nix).nixConfig) extra-substituters extra-trusted-public-keys;
in
{
  nix.settings = {
    trusted-users = [ "gehack" ];
    substituters = extra-substituters;
    trusted-public-keys = extra-trusted-public-keys;
  };
}
