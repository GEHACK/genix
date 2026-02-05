{
  description = "geproxy NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    disko.url = "github:nix-community/disko";
  };

  outputs =
    { nixpkgs, disko, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.geproxy = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./hosts/geproxy/configuration.nix
        ];
      };
    };
}
