{
  config,
  lib,
  pkgs,
  imaged_port,
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
      gawk
      systemd
    ];
    text = ''
      GEPROXY=${
        if config.teammachine.geproxy.discover then
          ''"$(resolvectl query --legend=no -4 ${config.teammachine.geproxy.host} | awk 'NR == 1 { print $2 }')"''
        else
          config.teammachine.geproxy.host
      }
      SERVER="http://$GEPROXY:${toString imaged_port}"
      BOOT="$SERVER/boot/${pkgs.stdenv.hostPlatform.linuxArch}"
      WORKDIR="$(mktemp -d)"
      trap 'rm -rf "$WORKDIR"' EXIT

      curl -fsSL "$BOOT/vmlinuz" -o "$WORKDIR/vmlinuz"
      curl -fsSL "$BOOT/initramfs.cpio.xz" -o "$WORKDIR/initramfs.cpio.xz"

      kexec -s -l "$WORKDIR/vmlinuz" \
        --initrd="$WORKDIR/initramfs.cpio.xz" \
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

  config = {
    environment.systemPackages =
      lib.optional cfg.pxe.enable pxeReboot ++ lib.optional cfg.imaged.enable imagedBoot;

    systemd.services.nouveau-release = lib.mkIf cfg.imaged.enable {
      description = "Release the GPUs from nouveau after the display manager, so GSP is torn down before a kexec";
      wantedBy = [ "multi-user.target" ];
      before = [
        "display-manager.service"
        "systemd-user-sessions.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = pkgs.writeShellScript "nouveau-release" ''
          ${lib.optionalString config.boot.plymouth.enable ''
            if ${config.boot.plymouth.package}/bin/plymouth --ping; then
              ${config.boot.plymouth.package}/bin/plymouth quit
            fi
          ''}
          for device in /sys/bus/pci/drivers/nouveau/0000:*; do
            if [ -e "$device" ]; then
              echo "''${device##*/}" > /sys/bus/pci/drivers/nouveau/unbind
            fi
          done
        '';
      };
    };
  };

}
