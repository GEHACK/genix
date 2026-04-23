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
    cuproxy.url = "github:GEHACK/cuproxy/feat/typst";
  };

  outputs =
    {
      nixpkgs,
      disko,
      home-manager,
      loom,
      sops-nix,
      cuproxy,
      ...
    }:
    let
      dj_url = "https://judge.gehack.nl";
      loom_url = "https://loom.gehack.nl";
      judge_ip = "10.0.0.1";
      contest_subnet = "10.0.0.0/24";
      specialArgs = {
        inherit
          dj_url
          loom_url
          judge_ip
          contest_subnet
          ;
      };

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
        cuproxy.nixosModules.default
        (mkHomeManager {
          gehack = import ./users/gehack;
        })
        ./hosts/geproxy/configuration.nix
      ];

      scoreboard-laptopModules = commonModules ++ [
        ./hosts/scoreboard-laptop/configuration.nix
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

      scoreboard-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = scoreboard-laptopModules;
      };

      teammachine-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = teammachineModules ++ [ vm-module ];
      };
    in
    {
      nixosConfigurations = {
        inherit
          teammachine
          teammachine_arm
          geproxy
          scoreboard-laptop
          ;
      };

      packages.x86_64-linux = {
        teammachine = teammachine.config.system.build.toplevel;
        geproxy = geproxy.config.system.build.toplevel;
        scoreboard-laptop = scoreboard-laptop.config.system.build.toplevel;
        teammachine-vm = teammachine-vm.config.system.build.vm;
      };

      packages.aarch64-linux = {
        teammachine-arm = teammachine_arm.config.system.build.toplevel;
      };
    };
}
