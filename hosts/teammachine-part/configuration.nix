{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  disko.enableConfig = false;

  fileSystems."/" = {
    device = "/dev/disk/by-label/teammachine";
    fsType = "ext4";
  };

  boot.loader.grub.enable = lib.mkForce false;

  system.build.partitionImage = import (modulesPath + "/../lib/make-disk-image.nix") {
    inherit config lib pkgs;
    partitionTableType = "none";
    label = "teammachine";
    baseName = "teammachine";
    copyChannel = false;
    installBootLoader = false;
  };
}
