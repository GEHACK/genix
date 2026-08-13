_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/geminecraft
  ];

  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth.enable = false;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "26.05";
}
