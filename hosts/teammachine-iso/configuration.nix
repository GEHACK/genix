{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")

    ../../modules

    # Full teammachine module set minus boot.nix (ISO provides its own bootloader)
    ../../modules/teammachine/desktop.nix
    ../../modules/teammachine/greeter.nix
    ../../modules/teammachine/ides.nix
    ../../modules/teammachine/languages.nix
    ../../modules/teammachine/locale.nix
    ../../modules/teammachine/loom.nix
    ../../modules/teammachine/misc-packages.nix
    ../../modules/teammachine/networking.nix
    ../../modules/teammachine/printer.nix
    ../../modules/teammachine/pxe-boot.nix
    ../../modules/teammachine/submit.nix
    ../../modules/teammachine/usbguard.nix
    ../../modules/teammachine/users.nix
    ../../modules/teammachine/webcamstream.nix
  ];

  # Decrypt secrets-iso.yaml using the iso-key baked into the image
  sops = {
    defaultSopsFile = lib.mkForce ../../secrets-iso.yaml;
    age.keyFile = lib.mkForce "/etc/sops/hostkey";
  };
  environment.etc."sops/hostkey" = {
    source = ../../iso-key;
    mode = "0400";
  };

  image.fileName = lib.mkForce "gehack-teammachine.iso";
  isoImage = {
    volumeID = lib.mkForce "GEHACK_ISO";
    makeEfiBootable = true;
    makeUsbBootable = true;
    squashfsCompression = "zstd -Xcompression-level 6";
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    enableRedistributableFirmware = true;
  };

  networking.hostName = lib.mkForce "gehack-iso";

  # Allow wifi/bluetooth on the live image
  boot.blacklistedKernelModules = lib.mkForce [ "algif_aead" ];
}
