{
  config,
  ...
}:
{

  config = {
    sops.secrets = {
      "cds.ccs.password" = { };
      "cds.admin.password" = { };
      "cds.presadmin.password" = { };
      "cds.presentation-client.password" = { };
      "cds.analyst.password" = { };
    };

    sops.templates."cds.env".content = ''
      CCS_URL=https://judge.gehack.nl/api/contests/__CONTEST__
      CCS_USER=admin
      CCS_PASSWORD=${config.sops.placeholder."cds.ccs.password"}
      ADMIN_PASSWORD=${config.sops.placeholder."cds.admin.password"}
      PRESADMIN_PASSWORD=${config.sops.placeholder."cds.presadmin.password"}
      PRESENTATION_PASSWORD=${config.sops.placeholder."cds.presentation-client.password"}
      LIVE_PASSWORD=${config.sops.placeholder."cds.analyst.password"}
    '';

    virtualisation.oci-containers = {
      backend = "docker";
      containers.cds = {
        image = "ghcr.io/icpctools/cds:2.7.1401";
        autoStart = true;
        ports = [ "8443:8443" ];
        volumes = [ "/var/lib/cds:/contest" ];
        environmentFiles = [ config.sops.templates."cds.env".path ];
      };
    };

    networking.firewall.allowedTCPPorts = [ 8443 ];
  };
}
