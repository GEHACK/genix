_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/geproxy
  ];

  home-manager.users.gehack.teammachine.neovim.enable = true;

  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth.enable = false;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
