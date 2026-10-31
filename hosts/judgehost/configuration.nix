_: {
  imports = [
    ./disko.nix
    ../../modules
    ../../modules/judgehost
    ../../modules/teammachine/geproxy.nix
    ../../modules/teammachine/netboot.nix
  ];

  judgehost.cores = [ 2 ];

  services.loomd.label = "judgehost";
  networking.hostName = "judgehost";
  monitoring.enable = true;
  teammachine.netboot.imaged.enable = true;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = false;

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
