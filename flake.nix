{
  description = "GEHACK NixOS configurations";

  nixConfig = {
    extra-substituters = [ "https://luukblankenstijn.cachix.org" ];
    extra-trusted-public-keys = [
      "luukblankenstijn.cachix.org-1:gRz/ypm8zdDizcdAuWD6UKLVBDeObfHsNDWoAka2WSw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    contest-greeter.url = "github:LuukBlankenstijn/contest-greeter";
  };

  outputs =
    {
      nixpkgs,
      disko,
      home-manager,
      contest-greeter,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        geproxy = nixpkgs.lib.nixosSystem {
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
        teammachine = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            contest-greeter.nixosModules.default
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.gehack = import ./users/gehack;
                users.team = import ./users/team;
              };
            }
            ./hosts/teammachine/configuration.nix
          ];
        };
        teammachine_arm = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            contest-greeter.nixosModules.default
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.gehack = import ./users/gehack;
                users.team = import ./users/team;
              };
            }
            ./hosts/teammachine/configuration.nix
          ];
        };
      };

      packages.x86_64-linux.teammachine-vm =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            contest-greeter.nixosModules.default
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.gehack = import ./users/gehack;
                users.team = import ./users/team;
              };
            }
            ./hosts/teammachine/configuration.nix
            (
              { modulesPath, ... }:
              {
                imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
                virtualisation = {
                  forwardPorts = [
                    {
                      from = "host";
                      host.port = 2222;
                      guest.port = 22;
                    }
                  ];
                  memorySize = 4096;
                  cores = 4;
                };
              }
            )
          ];
        }).config.system.build.vm;
    };
}
