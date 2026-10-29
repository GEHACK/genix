{
  description = "GEHACK NixOS configurations";

  nixConfig = {
    extra-substituters = [
      "https://luukblankenstijn.cachix.org"
      "https://gehack.cachix.org"
    ];
    extra-trusted-public-keys = [
      "luukblankenstijn.cachix.org-1:gRz/ypm8zdDizcdAuWD6UKLVBDeObfHsNDWoAka2WSw="
      "gehack.cachix.org-1:sjN0jwnXGRvA8lzoxc5bVkoSEW6VfjZuJL96vikglqc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko.url = "github:nix-community/disko";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    domjudge-submit = {
      url = "github:GEHACK/domjudge-submit-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    icpc-tools = {
      url = "github:GEHACK/icpc-tools-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    loom.url = "github:LuukBlankenstijn/loom";
    cuproxy.url = "github:GEHACK/cuproxy";
    balloons.url = "github:GEHACK/balloons/main";
    imaged.url = "github:LuukBlankenstijn/imaged";
    tunnelrs.url = "github:LuukBlankenstijn/tunnelrs";

    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bapctools = {
      url = "github:BHenkemans/nix-bapc-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      disko,
      home-manager,
      loom,
      sops-nix,
      cuproxy,
      imaged,
      tunnelrs,
      nixvim,
      domjudge-submit,
      icpc-tools,
      bapctools,
      ...
    }:
    let
      dj_url = "https://judge.gehack.nl";
      loom_url = "https://loom.gehack.nl";
      geproxy_ip = "10.0.0.1";
      contest_subnet = "10.0.0.0/24";
      admin_ip = "10.0.1.1";
      admin_subnet = "10.0.1.0/24";
      runtimes_host = "runtimes.gehack.nl";
      imaged_port = 8080;
      cds_port = 8443;
      contest_id = "main";
      specialArgs = {
        inherit
          dj_url
          loom_url
          geproxy_ip
          contest_subnet
          admin_ip
          admin_subnet
          runtimes_host
          imaged_port
          cds_port
          contest_id
          ;
      };

      isoSpecialArgs = specialArgs // {
        # Live demo image points at the public DOMjudge demo instance instead of
        # the contest judge (judge.gehack.nl is only reachable on the contest network).
        dj_url = "https://www.domjudge.org/demoweb/";
      };

      packageOverlays =
        { ... }:
        {
          nixpkgs.overlays = [
            domjudge-submit.overlays.default
            icpc-tools.overlays.default
          ];
        };

      commonModules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        packageOverlays
        loom.nixosModules.loomd
      ];

      mkHomeManager =
        {
          users,
          sharedModules ? [ ],
          extraSpecialArgs ? specialArgs,
        }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            inherit extraSpecialArgs users sharedModules;
          };
        };

      teammachineRoleModules = commonModules ++ [
        loom.nixosModules.loom-greeter
        (mkHomeManager {
          users = {
            gehack = import ./users/gehack;
            team = import ./users/team;
          };
          sharedModules = [
            nixvim.homeModules.nixvim
            ./users/common
          ];
        })
      ];

      teammachineModules = teammachineRoleModules ++ [ ./hosts/teammachine/configuration.nix ];

      geproxyRoleModules = commonModules ++ [
        cuproxy.nixosModules.default
        imaged.nixosModules.default
        loom.nixosModules.loom-backend
        tunnelrs.nixosModules.default
        (mkHomeManager {
          users = {
            gehack = import ./users/gehack;
          };
          sharedModules = [
            nixvim.homeModules.nixvim
            ./users/common
          ];
        })
        ({ ... }: { _module.args.balloons-pkg = inputs.balloons.packages.x86_64-linux.default; })
      ];

      geproxyModules = geproxyRoleModules ++ [ ./hosts/geproxy/configuration.nix ];

      utilityModules = commonModules ++ [
        (mkHomeManager {
          users = {
            gehack = import ./users/gehack;
          };
          sharedModules = [
            nixvim.homeModules.nixvim
            ./users/common
          ];
        })
        ./hosts/utility/configuration.nix
      ];

      judgehostModules = commonModules ++ [
        ./hosts/judgehost/configuration.nix
        ({ ... }: { _module.args.contestToolchain = teammachine.pkgs.contestToolchain; })
      ];

      cdsModules = commonModules ++ [
        ./hosts/cds/configuration.nix
      ];

      teammachine-isoModules = commonModules ++ [
        (mkHomeManager {
          users = {
            gehack = import ./users/gehack;
            team = import ./users/team;
          };
          sharedModules = [
            nixvim.homeModules.nixvim
            ./users/common
          ];
          extraSpecialArgs = isoSpecialArgs;
        })
        ./hosts/teammachine-iso/configuration.nix
      ];

      runtimes-isoModules = [
        { nixpkgs.overlays = [ bapctools.overlays.default ]; }
        ./hosts/runtimes-iso/configuration.nix
      ];

      mkVmModule =
        hostPort:
        { modulesPath, ... }:
        {
          imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
          virtualisation = {
            forwardPorts = [
              {
                from = "host";
                host.port = hostPort;
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

      teammachine-part = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = teammachineRoleModules ++ [ ./hosts/teammachine-part/configuration.nix ];
      };

      teammachine-part-base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = teammachineRoleModules ++ [ ./hosts/teammachine-part/base.nix ];
      };

      geproxy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = geproxyModules;
      };

      utility = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = utilityModules;
      };

      judgehost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = judgehostModules;
      };

      cds = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = cdsModules;
      };

      teammachine-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = teammachineModules ++ [
          (mkVmModule 2222)
          {
            virtualisation.forwardPorts = [
              {
                from = "host";
                host.port = 13389;
                guest.port = 3389;
              }
            ];
          }
        ];
      };

      geproxy-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = geproxyModules ++ [ (mkVmModule 2223) ];
      };

      judgehost-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = judgehostModules ++ [ (mkVmModule 2224) ];
      };

      utility-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = utilityModules ++ [ (mkVmModule 2225) ];
      };

      teammachine-iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = isoSpecialArgs;
        modules = teammachine-isoModules;
      };

      runtimes-iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit specialArgs;
        modules = runtimes-isoModules;
      };
    in
    {
      nixosConfigurations = {
        inherit
          teammachine
          teammachine-part
          teammachine-part-base
          geproxy
          utility
          judgehost
          cds
          teammachine-iso
          runtimes-iso
          ;
      };

      packages.x86_64-linux = {
        teammachine = teammachine.config.system.build.toplevel;
        teammachine-part = teammachine-part-base.config.system.build.partitionImage;
        geproxy = geproxy.config.system.build.toplevel;
        utility = utility.config.system.build.toplevel;
        teammachine-vm = teammachine-vm.config.system.build.vm;
        geproxy-vm = geproxy-vm.config.system.build.vm;
        judgehost = judgehost.config.system.build.toplevel;
        cds = cds.config.system.build.toplevel;
        judgehost-vm = judgehost-vm.config.system.build.vm;
        utility-vm = utility-vm.config.system.build.vm;
        teammachine-iso = teammachine-iso.config.system.build.isoImage;
        runtimes-iso = runtimes-iso.config.system.build.isoImage;
        nixos-anywhere = nixpkgs.legacyPackages.x86_64-linux.nixos-anywhere;
      };

      checks.x86_64-linux = {
        teammachine-rdp = import ./tests/teammachine-rdp.nix {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          sopsModule = sops-nix.nixosModules.sops;
          inherit (nixpkgs) lib;
        };
        geproxy-network = import ./tests/geproxy-network.nix {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          sopsModule = sops-nix.nixosModules.sops;
          inherit (nixpkgs) lib;
        };
      };
    };
}
