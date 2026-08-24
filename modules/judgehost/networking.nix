{
  judge_ip,
  lib,
  pkgs,
  ...
}:
let
  deriveHostname = pkgs.writeShellApplication {
    name = "judgehost-derive-hostname";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      primary_mac() {
        local dev
        for dev in /sys/class/net/*; do
          [ -r "$dev/address" ] || continue
          case "$(readlink -f "$dev")" in
          */devices/virtual/*) continue ;;
          esac
          tr -d : <"$dev/address"
          return 0
        done
        return 1
      }

      for _ in $(seq 30); do
        mac=$(primary_mac) && break
        sleep 1
      done

      if [ -z "''${mac:-}" ]; then
        echo "judgehost: no physical network interface appeared to derive a hostname from" >&2
        exit 1
      fi

      hostnamectl set-hostname --transient "judge-''${mac: -6}"
    '';
  };
in
{
  # DOMjudge registers each daemon as "<hostname>-<DAEMON_ID>", so every machine needs
  # its own name. Deriving it from the primary NIC's MAC keeps that unique without a
  # per-machine host config or dhcp-host reservations on geproxy.
  networking = {
    hostName = "";
    dhcpcd.setHostname = false;
  };

  # Ordering against udev is deliberately absent: systemd-udev-settle.service is not
  # part of the NixOS unit set, so an After= on it would silently do nothing. The
  # script waits for the interface itself instead.
  systemd.services.judgehost-hostname = {
    description = "Derive the hostname from the primary interface's MAC address";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-udevd.service"
      "systemd-hostnamed.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe deriveHostname;
    };
  };

  services.timesyncd.servers = [ judge_ip ];
}
