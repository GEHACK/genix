{ lib, config, ... }:
{
  options.geproxy.raidBoot.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Boot from a two-disk mdadm RAID1 with mirrored GRUB installs on /dev/sda and /dev/sdb.";
  };

  config = lib.mkIf config.geproxy.raidBoot.enable {
    boot = {
      swraid = {
        enable = true;
        mdadmConf = ''
          MAILADDR root
        '';
      };

      loader = {
        systemd-boot.enable = false;
        grub = {
          enable = true;
          efiSupport = true;
          efiInstallAsRemovable = true;
          devices = [ "nodev" ];
          mirroredBoots = [
            {
              path = "/boot";
              devices = [ "/dev/sda" ];
            }
            {
              path = "/boot-fallback";
              devices = [ "/dev/sdb" ];
            }
          ];
        };
      };

      initrd = {
        kernelModules = [
          "ext4"
          "md_mod"
          "raid1"
        ];
      };
    };
  };
}
