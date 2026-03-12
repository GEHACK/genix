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

    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      sops-nix,
      ...
    }:
    let
      dj_url = "https://dj.bartjan.tech";
      specialArgs = { inherit dj_url; };

      commonModules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
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

      geproxyModules = commonModules ++ [
        (mkHomeManager {
          gehack = import ./users/gehack;
        })
        ./hosts/geproxy/configuration.nix
      ];

      vm-module =
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
        };

      teammachine-bare = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = commonModules ++ [
          ./hosts/teammachine/disko.nix
          ./modules/teammachine/boot.nix
          ./modules
          {
            time.timeZone = "Europe/Amsterdam";
            i18n.defaultLocale = "en_US.UTF-8";
            system.stateVersion = "25.11";
          }
        ];
      };

      teammachine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = teammachineModules;
      };

      teammachine_arm = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        inherit specialArgs;
        modules = teammachineModules;
      };

      geproxy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = geproxyModules;
      };

      teammachine-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = teammachineModules ++ [ vm-module ];
      };
    in
    {
      nixosConfigurations = { inherit teammachine teammachine-bare teammachine_arm geproxy; };

      packages.x86_64-linux = {
        teammachine = teammachine.config.system.build.toplevel;
        geproxy = geproxy.config.system.build.toplevel;
        teammachine-vm = teammachine-vm.config.system.build.vm;
      };

      packages.aarch64-linux = {
        teammachine-arm = teammachine_arm.config.system.build.toplevel;
      };
    };
}

