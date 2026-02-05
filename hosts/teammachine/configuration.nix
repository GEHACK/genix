_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/teammachine
  ];

  hardware.enableRedistributableFirmware = true;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
