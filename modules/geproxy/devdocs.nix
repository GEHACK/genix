{ lib, config, ... }:
{
  options.geproxy.devdocs.enable = lib.mkEnableOption "DevDocs as proxy site `docs`";

  config = lib.mkIf config.geproxy.devdocs.enable {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.devdocs = {
        image = "ghcr.io/gehack/devdocs:latest-alpine";
        autoStart = true;
        extraOptions = [
          "--platform=linux/amd64"
          "--pull=always"
        ];
        ports = [ "127.0.0.1:3002:9292" ];
      };
    };

    geproxy.proxy.sites.docs.upstream = "http://127.0.0.1:3002";
  };
}
