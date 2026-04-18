{ pkgs, ... }:

let
  pxe-reboot = pkgs.writeShellApplication {
    name = "pxe-reboot";
    runtimeInputs = with pkgs; [
      efibootmgr
      systemd
      gnugrep
      gawk
    ];
    text = ''
      boot_id=$(efibootmgr | awk '/[iI][pP][vV]4/ && !/BBS/ {sub(/^Boot/, "", $1); sub(/\*/, "", $1); print $1; exit}')

      if [ -z "''${boot_id:-}" ]; then
        echo "error: no IPv4/PXE boot entry found in efibootmgr output" >&2
        echo "available entries:" >&2
        efibootmgr >&2
        exit 1
      fi

      sudo efibootmgr --bootnext "$boot_id" >/dev/null

      sudo systemctl reboot
    '';
  };
in
{
  environment.systemPackages = [ pxe-reboot ];
}
