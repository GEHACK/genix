{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")

    ../../modules/nix.nix
    ../../modules/security.nix
    ../../modules/ssh.nix

    ../../modules/teammachine/desktop.nix
    ../../modules/teammachine/ides.nix
    ../../modules/teammachine/languages.nix
    ../../modules/teammachine/locale.nix
    ../../modules/teammachine/misc-packages.nix
    ../../modules/teammachine/printer.nix
    ../../modules/teammachine/submit.nix
    ../../modules/teammachine/webcamstream.nix
  ];

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
      enable32Bit = pkgs.stdenv.hostPlatform.isx86_64;
    };
    enableRedistributableFirmware = true;
  };

  networking = {
    hostName = "gehack-iso";
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
    wireless.enable = lib.mkForce false;
    firewall.enable = lib.mkForce false;
  };

  users = {
    mutableUsers = true;
    users = {
      root.initialPassword = "root";
      gehack = {
        isNormalUser = true;
        initialPassword = "gehack";
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
        ];
        shell = pkgs.zsh;
      };
      team = {
        isNormalUser = true;
        initialPassword = "team";
        extraGroups = [
          "networkmanager"
          "video"
          "audio"
        ];
      };
    };
  };

  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  services.displayManager = {
    gdm.enable = lib.mkForce true;
    autoLogin = {
      enable = true;
      user = "team";
    };
  };

  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";
}
