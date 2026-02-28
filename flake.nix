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

    loom.url = "github:LuukBlankenstijn/loom";
  };

  outputs =
    {
      nixpkgs,
      disko,
      home-manager,
      loom,
      ...
    }:
    let
      dj_url = "https://dj.bartjan.tech";
      specialArgs = { inherit dj_url; };

      commonModules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
      ];

      mkHomeManager = users: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = specialArgs;
          inherit users;
        };
      };

      teammachineModules = commonModules ++ [
        loom.nixosModules.default
        (mkHomeManager {
          gehack = import ./users/gehack;
          team = import ./users/team;
        })
        ./hosts/teammachine/configuration.nix
      ];

      mkTeammachine = system:
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = teammachineModules;
        };
    in
    {
      nixosConfigurations = {
        geproxy = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit specialArgs;
          modules = commonModules ++ [
            (mkHomeManager {
              gehack = import ./users/gehack;
            })
            ./hosts/geproxy/configuration.nix
          ];
        };

        teammachine = mkTeammachine "x86_64-linux";
        teammachine_arm = mkTeammachine "aarch64-linux";
      };

      packages.x86_64-linux.teammachine-vm =
        (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit specialArgs;
          modules = teammachineModules ++ [
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
