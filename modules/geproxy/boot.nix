_: {
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

}
