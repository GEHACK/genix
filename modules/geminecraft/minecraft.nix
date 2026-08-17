{
  config,
  lib,
  pkgs,
  ...
}:
let
  bridgeAddress = "10.0.0.1";
  dataDir = "/var/lib/minecraft";
  network = "minecraft";
  networkBridge = "mc0";
  gameVersion = "26.2";

  flatWorld = ''{"layers":[{"block":"minecraft:bedrock","height":1}],"biome":"minecraft:the_void"}'';

  fabricMods = [
    "fabric-api"
    "lithium"
    "ferrite-core"
    "krypton"
    "spark"
  ];

  worlds = {
    bedwars = {
      memory = "20%";
      type = "PAPER";
      projects = [ "screamingbedwars" ];
      properties = {
        MODE = "survival";
        DIFFICULTY = "easy";
        LEVEL = "arena";
        SPAWN_PROTECTION = "0";
        MAX_PLAYERS = "8";
      };
    };
    survival = {
      memory = "40%";
      projects = [ ];
      datapack = ./assets/lobby-menu;
      properties = {
        MODE = "survival";
        DIFFICULTY = "normal";
        MAX_PLAYERS = "50";
      };
    };
    creative = {
      memory = "12%";
      projects = [ "worldedit" ];
      properties = {
        MODE = "creative";
        FORCE_GAMEMODE = "TRUE";
        DIFFICULTY = "peaceful";
        MAX_PLAYERS = "50";
      };
    };
  };

  worldDir = world: world.properties.LEVEL or "world";

  serverType = world: world.type or "FABRIC";

  projectsFor =
    world:
    (lib.optionals (serverType world == "FABRIC") fabricMods) ++ (world.projects or [ ]);

  mkWorld = name: world: {
    image = "itzg/minecraft-server:java25";
    volumes = [ "${dataDir}/${name}:/data" ];
    networks = [ network ];
    extraOptions = [ "--stop-timeout=120" ];
    environment = {
      EULA = "TRUE";
      TYPE = serverType world;
      VERSION = gameVersion;
      MEMORY = world.memory;
      USE_AIKAR_FLAGS = "true";
      ONLINE_MODE = "FALSE";
      ENABLE_WHITELIST = "FALSE";
      MODRINTH_DOWNLOAD_DEPENDENCIES = "required";
      MODRINTH_PROJECTS = lib.concatStringsSep "," (projectsFor world);
    }
    // world.properties;
  };

  containers = lib.mapAttrs mkWorld worlds // {
    minecraft = {
      image = "itzg/mc-proxy:java25";
      volumes = [
        "${dataDir}/proxy:/server"
        "${./assets/velocity.toml}:/config/velocity.toml:ro"
      ];
      networks = [ network ];
      ports = [ "${bridgeAddress}:25565:25565/tcp" ];
      extraOptions = [ "--stop-timeout=60" ];
      environment = {
        TYPE = "VELOCITY";
        MEMORY = "512M";
        SYNC_SKIP_NEWER_IN_DESTINATION = "false";
      };
    };
  };

  withDatapack = lib.filterAttrs (_: world: world ? datapack) worlds;
in
{
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    inherit containers;
  };

  systemd.services = {
    minecraft-network = {
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      path = [ config.virtualisation.docker.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        docker network inspect ${network} > /dev/null 2>&1 ||
          docker network create --opt com.docker.network.bridge.name=${networkBridge} ${network}
      '';
    };

    minecraft-datapacks = {
      wantedBy = [ "multi-user.target" ];
      before = map (name: "docker-${name}.service") (lib.attrNames withDatapack);
      path = [ pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStrings (
        lib.mapAttrsToList (
          name: world:
          let
            target = "${dataDir}/${name}/${worldDir world}/datapacks/${baseNameOf world.datapack}";
          in
          ''
            install -d -o 1000 -g 1000 -m 0755 ${dirOf target}
            rm -rf ${target}
            cp -rT ${world.datapack} ${target}
            chmod -R u+w ${target}
            chown -R 1000:1000 ${target}
          ''
        ) withDatapack
      );
    };
  }
  // lib.genAttrs (map (name: "docker-${name}") (lib.attrNames containers)) (_: {
    after = [ "minecraft-network.service" ];
    requires = [ "minecraft-network.service" ];
  });

  systemd.tmpfiles.rules =
    map (name: "d ${dataDir}/${name} 0755 1000 1000 -") (lib.attrNames worlds ++ [ "proxy" ])
    ++ lib.mapAttrsToList (
      name: world: "d ${dataDir}/${name}/${worldDir world} 0755 1000 1000 -"
    ) withDatapack;
}
