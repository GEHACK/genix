_:
let
  bridgeAddress = "10.0.0.1";
  dataDir = "/var/lib/minecraft";
in
{
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.minecraft = {
      image = "itzg/minecraft-server:java25";
      volumes = [ "${dataDir}:/data" ];
      ports = [
        "${bridgeAddress}:25565:25565/tcp"
        "${bridgeAddress}:24454:24454/udp"
      ];
      environment = {
        EULA = "TRUE";
        TYPE = "FABRIC";
        MEMORY = "8G";
        USE_AIKAR_FLAGS = "true";
        ONLINE_MODE = "FALSE";
        ENABLE_WHITELIST = "FALSE";
        MOTD = "GEHACK";
        VERSION_FROM_MODRINTH_PROJECTS = "true";
        MODRINTH_DOWNLOAD_DEPENDENCIES = "required";
        MODRINTH_PROJECTS = builtins.concatStringsSep "," [
          "fabric-api"
          "lithium"
          "ferrite-core"
          "krypton"
          "simple-voice-chat"
          "spark?"
        ];
      };
      extraOptions = [ "--stop-timeout=120" ];
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 1000 1000 -" ];
}
