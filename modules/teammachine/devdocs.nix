{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 80 ];
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      "devdocs" = {
        image = "ghcr.io/gehack/devdocs:latest-alpine"; 
        autoStart = true;
        extraOptions = [ 
          "--platform=linux/amd64" 
          "--pull=always" 
          ];
        ports = [ "127.0.0.1:80:9292" ];
      };
    };
  };
}