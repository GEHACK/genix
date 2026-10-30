{ lib, config, ... }:
let
  upstream = "http://127.0.0.1:3002";
in
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
        environment.PERMITTED_HOSTS = lib.concatStringsSep "," (
          lib.mapAttrsToList (_: site: site.host) (
            lib.filterAttrs (_: site: site.upstream == upstream) config.geproxy.proxy.sites
          )
        );
      };
    };

    geproxy.proxy.sites.docs = { inherit upstream; };
  };
}
