{
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix")
    ../../modules/nix.nix
    ../../modules/ssh.nix
    ../../modules/teammachine/desktop.nix
    ../../modules/teammachine/devdocs.nix
    ../../modules/teammachine/ides.nix
    ../../modules/teammachine/languages.nix
    ../../modules/teammachine/locale.nix
    ../../modules/teammachine/misc-packages.nix
    ../../modules/teammachine/networking.nix
    ../../modules/teammachine/printer.nix
    ../../modules/teammachine/submit.nix
    ../../modules/teammachine/usbguard.nix
    ../../modules/teammachine/webcamstream.nix
  ];

  image.baseName = lib.mkForce "gehack-teammachine";
  isoImage.squashfsCompression = "lz4";

  # GDM + auto-login (desktop.nix disables GDM for loom-greeter, ISO needs it back)
  services.displayManager.gdm.enable = lib.mkForce true;
  services.displayManager.autoLogin = {
    enable = true;
    user = lib.mkForce "team";
  };

  # Users with simple passwords (no sops)
  users.mutableUsers = true;
  users.users = {
    team = {
      isNormalUser = true;
      extraGroups = [ "wheel" "docker" ];
      initialPassword = "team";
    };
    gehack = {
      isNormalUser = true;
      extraGroups = [ "wheel" "docker" ];
      shell = pkgs.zsh;
      initialPassword = "gehack";
    };
  };

  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
