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
      boot_id=$(efibootmgr \
        | grep -iE 'Boot[0-9A-F]{4}.*(IPv?4|PXE.*IP?v?4|IP?v?4.*PXE)' \
        | head -n1 \
        | awk '{print $1}' \
        | sed 's/^Boot//; s/\*$//')

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
