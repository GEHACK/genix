{
  config,
  lib,
  pkgs,
  geproxy_ip,
  ...
}:
let
  cfg = config.teammachine.geproxy;

  name = "geproxy.local";
  domain = "gehack.nl";

  discover = pkgs.writeShellApplication {
    name = "geproxy-discover";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      nftables
      systemd
    ];
    text = ''
      for dev in /sys/class/net/*; do
        case "$(readlink -f "$dev")" in
        */devices/virtual/*) continue ;;
        esac
        resolvectl mdns "$(basename "$dev")" resolve || true
      done

      address="$(resolvectl query --legend=no -4 -p mdns ${name} 2>/dev/null | awk 'NR == 1 { print $2 }' || true)"
      if [[ ! "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "geproxy-discover: ${name} does not resolve over mDNS" >&2
        exit 1
      fi

      if nft list set inet filter geproxy >/dev/null 2>&1; then
        nft -f - <<EOF
      flush set inet filter geproxy
      add element inet filter geproxy { $address }
      EOF
      fi

      conf=/run/systemd/resolved.conf.d/geproxy.conf
      wanted="$(printf '[Resolve]\nDNS=%s\nDomains=~${domain}' "$address")"
      if [[ "$(cat "$conf" 2>/dev/null)" != "$wanted" ]]; then
        mkdir -p "$(dirname "$conf")"
        printf '%s\n' "$wanted" > "$conf"
        systemctl reload systemd-resolved.service
        echo "geproxy-discover: geproxy is at $address"
      fi
    '';
  };
in
{
  options.teammachine.geproxy = {
    discover = lib.mkEnableOption ''
      finding geproxy as `${name}` over mDNS instead of at its fixed contest
      address. The firewall follows the address, and DNS for `${domain}` goes to it
    '';

    trigger = lib.mkOption {
      type = lib.types.enum [
        "timer"
        "dispatcher"
      ];
      default = "timer";
      description = ''
        When to look geproxy up: `timer` every 30 seconds, `dispatcher` when
        NetworkManager brings a connection up or renews its lease, retrying
        until geproxy answers.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      internal = true;
      default = if cfg.discover then name else geproxy_ip;
      description = "Name or address services use to reach geproxy.";
    };
  };

  config = lib.mkIf cfg.discover {
    networking.firewall.allowedUDPPorts = [ 5353 ];

    services.resolved = {
      enable = true;
      settings.Resolve = {
        MulticastDNS = "resolve";
        FallbackDNS = "";
      };
    };

    networking.networkmanager = {
      dns = "systemd-resolved";
      connectionConfig."connection.mdns" = 1;
    };

    systemd.services.geproxy-discover = {
      description = "Find geproxy over mDNS";
      after = [
        "nftables.service"
        "systemd-resolved.service"
      ];
      wantedBy = lib.mkIf (cfg.trigger == "timer") [ "nftables.service" ];
      unitConfig.StartLimitIntervalSec = lib.mkIf (cfg.trigger == "dispatcher") 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe discover;
      }
      // lib.optionalAttrs (cfg.trigger == "dispatcher") {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.timers.geproxy-discover = lib.mkIf (cfg.trigger == "timer") {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5s";
        OnUnitInactiveSec = "30s";
      };
    };

    networking.networkmanager.dispatcherScripts = lib.mkIf (cfg.trigger == "dispatcher") [
      {
        type = "basic";
        source = pkgs.writeShellScript "geproxy-discover-dispatcher" ''
          case "$2" in
            up | dhcp4-change) ${pkgs.systemd}/bin/systemctl start --no-block geproxy-discover.service ;;
          esac
        '';
      }
    ];
  };
}
