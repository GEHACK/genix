{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.teammachine.netboot;

  pxeReboot = pkgs.writeShellApplication {
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

  imagedBoot = pkgs.writeShellApplication {
    name = "imaged-boot";
    runtimeInputs = with pkgs; [
      kexec-tools
      curl
      coreutils
      systemd
    ];
    text = ''
      SERVER="http://10.0.0.1:8080"
      WORKDIR="$(mktemp -d)"
      trap 'rm -rf "$WORKDIR"' EXIT

      curl -fsSL "$SERVER/boot/vmlinuz" -o "$WORKDIR/vmlinuz"
      curl -fsSL "$SERVER/boot/initramfs.cpio.gz" -o "$WORKDIR/initramfs.cpio.gz"

      kexec -s -l "$WORKDIR/vmlinuz" \
        --initrd="$WORKDIR/initramfs.cpio.gz" \
        --command-line="img_srv=$SERVER console=ttyS0,115200n8 console=tty0 ignore_loglevel"

      systemctl kexec
    '';
  };
in
{
  options.teammachine.netboot = {
    pxe.enable = lib.mkEnableOption "pxe-reboot helper (reboot into network boot)";
    imaged.enable = lib.mkEnableOption "imaged kexec helper (kexec into imaged kernel)";
  };

  config.environment.systemPackages =
    lib.optional cfg.pxe.enable pxeReboot ++ lib.optional cfg.imaged.enable imagedBoot;

}
