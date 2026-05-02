_: {
  boot = {
    kernelParams = [ "video=eDP-1:d" ];
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
