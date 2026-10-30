{ lib, config, ... }:
let
  metricsAddr = "127.0.0.1:8428";
  lokiPort = 3100;
  grafanaPort = 3020;
  token = config.sops.secrets."monitoring.token".path;
in
{
  options.geproxy.monitoring.enable = lib.mkEnableOption "VictoriaMetrics and Loki receiving pushes as proxy site `metrics`, and Grafana as proxy site `grafana`";

  config = lib.mkIf config.geproxy.monitoring.enable {
    sops.secrets = {
      "monitoring.token" = {
        owner = config.services.caddy.user;
        restartUnits = [ "caddy.service" ];
      };
      "grafana.secretKey" = {
        owner = "grafana";
        restartUnits = [ "grafana.service" ];
      };
    };

    services.victoriametrics = {
      enable = true;
      listenAddress = metricsAddr;
      retentionPeriod = "90d";
    };

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = lokiPort;
          grpc_listen_address = "127.0.0.1";
        };
        common = {
          path_prefix = config.services.loki.dataDir;
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
          storage.filesystem = {
            chunks_directory = "${config.services.loki.dataDir}/chunks";
            rules_directory = "${config.services.loki.dataDir}/rules";
          };
        };
        schema_config.configs = [
          {
            from = "2026-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        limits_config.retention_period = "90d";
        compactor = {
          working_directory = "${config.services.loki.dataDir}/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = grafanaPort;
          root_url = "https://${config.geproxy.proxy.sites.grafana.host}";
        };
        security.secret_key = "$__file{${config.sops.secrets."grafana.secretKey".path}}";
        "auth.anonymous" = {
          enabled = true;
          org_role = "Admin";
        };
        auth.disable_login_form = true;
        analytics.reporting_enabled = false;
      };
      provision.datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          type = "prometheus";
          url = "http://${metricsAddr}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${toString lokiPort}";
        }
      ];
    };

    geproxy.proxy.sites = {
      metrics = {
        upstream = "http://${metricsAddr}";
        extraConfig = ''
          @unauthorized not header Authorization "Bearer {file.${token}}"
          respond @unauthorized 401
          reverse_proxy /loki/api/v1/push 127.0.0.1:${toString lokiPort}
          @other not path /api/v1/write
          respond @other 404
        '';
      };
      grafana = {
        upstream = "http://127.0.0.1:${toString grafanaPort}";
        login = true;
      };
    };
  };
}
