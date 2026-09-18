_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/cds
  ];

  networking.hostName = "cds";

  hardware.enableRedistributableFirmware = true;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
