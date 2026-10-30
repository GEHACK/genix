_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/utility
    ../../modules/teammachine/geproxy.nix
    ../../modules/teammachine/netboot.nix
  ];

  networking.hostName = "utility";

  services.loomd.label = "utility";
  monitoring.enable = true;
  teammachine.netboot.imaged.enable = true;
  teammachine.geproxy.discover = true;

  hardware.enableRedistributableFirmware = true;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
