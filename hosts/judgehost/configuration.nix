_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/judgehost
  ];

  judgehost.cores = [ 2 ];

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = false;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
