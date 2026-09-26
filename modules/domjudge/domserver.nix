{ config, pkgs, ... }:
let
  domserverImage = pkgs.dockerTools.pullImage {
    imageName = "domjudge/domserver";
    imageDigest = "sha256:2fa335b7214af40732406b5f6e686d7dc942b559f272367f8d8fae1fef2eef41";
    hash = "sha256-/eyDHZj/ksTIyA0d0LEuFVhKzIiRowPi/0K++YlFP3o=";
    finalImageName = "domjudge/domserver";
    finalImageTag = "bleeding";
    os = "linux";
    arch = "amd64";
  };

  mariadbImage = pkgs.dockerTools.pullImage {
    imageName = "mariadb";
    imageDigest = "sha256:70cc072b29b4a89ae07abb2d4da2c64678a7f2dfe092751bb51c87d67dc1338b";
    hash = "sha256-XN0YZQDMjHFpZL7Fo31zknPPYQAXY37RUhDDOLvQ6MM=";
    finalImageName = "mariadb";
    finalImageTag = "11.4";
    os = "linux";
    arch = "amd64";
  };

  database = {
    MYSQL_HOST = "127.0.0.1";
    MYSQL_DATABASE = "domjudge";
    MYSQL_USER = "domjudge";
  };

  installRestapiSecret = pkgs.writeScript "40-judgehost-restapi" ''
    #!/bin/sh
    cp /run/judgehost-restapi.secret /opt/domjudge/domserver/etc/restapi.secret
  '';
in
{
  sops.secrets = {
    "domjudge.mysql.password" = { };
    "domjudge.mysql.root-password" = { };
    "judgehost.password" = { };
  };

  sops.templates."domjudge-mysql.env".content = ''
    MYSQL_PASSWORD=${config.sops.placeholder."domjudge.mysql.password"}
    MYSQL_ROOT_PASSWORD=${config.sops.placeholder."domjudge.mysql.root-password"}
  '';

  sops.templates."domjudge-restapi.secret".content = ''
    default	http://localhost/	judgehost	${config.sops.placeholder."judgehost.password"}
  '';

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      mariadb = {
        imageFile = mariadbImage;
        image = "mariadb:11.4";
        autoStart = true;
        environment = database;
        environmentFiles = [ config.sops.templates."domjudge-mysql.env".path ];
        volumes = [ "/var/lib/mariadb:/var/lib/mysql" ];
        cmd = [
          "--bind-address=127.0.0.1"
          "--max-connections=1000"
          "--max-allowed-packet=1G"
        ];
        extraOptions = [ "--network=host" ];
      };

      domserver = {
        imageFile = domserverImage;
        image = "domjudge/domserver:bleeding";
        autoStart = true;
        dependsOn = [ "mariadb" ];
        environment = database // {
          CONTAINER_TIMEZONE = config.time.timeZone;
        };
        environmentFiles = [ config.sops.templates."domjudge-mysql.env".path ];
        volumes = [
          "${config.sops.templates."domjudge-restapi.secret".path}:/run/judgehost-restapi.secret:ro"
          "${installRestapiSecret}:/scripts/start.ro/40-judgehost-restapi:ro"
        ];
        extraOptions = [ "--network=host" ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
