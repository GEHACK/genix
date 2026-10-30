{
  lib,
  config,
  ...
}:
let
  token = "/run/credentials/alloy.service/token";
  server = "https://metrics.gehack.nl";
in
{
  options.monitoring.enable = lib.mkEnableOption "node metrics and the journal, pushed to geproxy's VictoriaMetrics and Loki";

  config = lib.mkIf config.monitoring.enable {
    sops.secrets."monitoring.token".restartUnits = [ "alloy.service" ];

    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      enabledCollectors = [ "systemd" ];
    };

    services.alloy.enable = true;
    systemd.services.alloy.serviceConfig = {
      LoadCredential = [ "token:${config.sops.secrets."monitoring.token".path}" ];
      TimeoutStopSec = "5s";
    };

    environment.etc."alloy/config.alloy".text = ''
      local.file "machine_id" {
        filename = "/etc/machine-id"
      }

      prometheus.scrape "node" {
        targets         = [{ "__address__" = "127.0.0.1:${toString config.services.prometheus.exporters.node.port}", "host" = "${config.networking.hostName}", "machine" = string.trim_space(local.file.machine_id.content) }]
        scrape_interval = "15s"
        forward_to      = [prometheus.remote_write.geproxy.receiver]
      }

      prometheus.remote_write "geproxy" {
        endpoint {
          url               = "${server}/api/v1/write"
          bearer_token_file = "${token}"
        }
      }

      loki.source.journal "journal" {
        labels     = { "host" = "${config.networking.hostName}", "machine" = string.trim_space(local.file.machine_id.content) }
        forward_to = [loki.write.geproxy.receiver]
      }

      loki.write "geproxy" {
        endpoint {
          url               = "${server}/loki/api/v1/push"
          bearer_token_file = "${token}"
        }
      }
    '';
  };
}
