{ lib, pkgs, ... }:
{
  imports = [
    ../../modules
    ../../modules/teammachine
    ../../modules/partition
  ];

  teammachine = {
    netboot.imaged.enable = true;
    geproxy.discover = true;
  };

  hardware = {
    graphics = {
      enable = true;
      extraPackages = [ pkgs.intel-media-driver ];
    };
    enableRedistributableFirmware = true;
  };

  services.orca.enable = false;
  services.speechd.enable = false;

  nixpkgs.config.allowUnfree = true;

  sops.defaultSopsFile = lib.mkForce ../../secrets-teammachine.yaml;

  system.stateVersion = "25.11";
}
