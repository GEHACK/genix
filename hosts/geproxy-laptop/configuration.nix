_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/geproxy
  ];

  geproxy = {
    raidBoot.enable = false;
    network = {
      uplink = "wlp0s20f3";
      contestInterfaces = [ "enp0s31f6" ];
      admin.enable = false;
    };
  };

  boot.loader = {
    systemd-boot.enable = false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      devices = [ "nodev" ];
    };
  };

  home-manager.users.gehack.teammachine.neovim.enable = true;

  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth.enable = false;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
