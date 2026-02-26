_: {
  boot = {
    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        devices = [ "nodev" ];
      };
    };
  };
}
