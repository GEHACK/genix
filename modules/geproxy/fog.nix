_: {
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      "fog-db" = {
        image = "mariadb:10.11";
        autoStart = true;
        volumes = [ "fog-db-data:/var/lib/mysql" ];
        environment = {
          MARIADB_ROOT_PASSWORD = "fogR00tP4ss";
          MARIADB_DATABASE = "fog";
          MARIADB_USER = "fogmaster";
          MARIADB_PASSWORD = "fogmaster123";
        };
        ports = [ "127.0.0.1:3306:3306" ];
      };

      "fog-server" = {
        image = "ghcr.io/88fingerslukee/fog-docker:latest";
        autoStart = true;
        dependsOn = [ "fog-db" ];
        volumes = [
          "fog-images:/images"
          "fog-tftpboot:/tftpboot"
          "fog-snapins:/opt/fog/snapins"
          "fog-logs:/opt/fog/log"
          "fog-ssl:/opt/fog/snapins/ssl"
          "fog-config:/opt/fog/config"
          "fog-secure-boot:/opt/fog/secure-boot"
        ];
        environment = {
          # Database - reachable on localhost via host networking
          FOG_DB_HOST = "127.0.0.1";
          FOG_DB_PORT = "3306";
          FOG_DB_NAME = "fog";
          FOG_DB_USER = "fogmaster";
          FOG_DB_PASS = "fogmaster123";

          # Web - Apache on 3001, Traefik proxies from :3000
          FOG_WEB_HOST = "fog.gehack.nl";
          FOG_WEB_ROOT = "/fog";
          FOG_APACHE_PORT = "3001";

          # Reverse proxy mode: Traefik handles HTTPS
          FOG_INTERNAL_HTTPS_ENABLED = "false";
          FOG_HTTP_PROTOCOL = "https";

          # Network - use contest bridge IP (resolves via dnsmasq wildcard)
          FOG_STORAGE_HOST = "10.0.0.1";
          FOG_WOL_HOST = "10.0.0.1";
          FOG_TFTP_HOST = "10.0.0.1";
          FOG_MULTICAST_INTERFACE = "br-contest";

          # FTP
          FOG_USER = "fogproject";
          FOG_PASS = "fogftp123";
          FOG_FTP_PASV_MIN_PORT = "21100";
          FOG_FTP_PASV_MAX_PORT = "21110";

          # DHCP disabled - using existing dnsmasq
          FOG_DHCP_ENABLED = "false";

          TZ = "Europe/Amsterdam";
          DEBUG = "true";
        };
        extraOptions = [
          "--privileged"
          "--network=host"
        ];
      };
    };
  };
}
