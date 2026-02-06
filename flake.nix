{
  description = "GEHACK NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.geproxy = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.gehack = import ./users/gehack;
            };
          }
          ./hosts/geproxy/configuration.nix
        ];
      };
    };
}
