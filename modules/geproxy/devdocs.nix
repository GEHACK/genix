_:

{
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
        ports = [ "127.0.0.1:3002:9292" ];
      };
    };
  };
}

