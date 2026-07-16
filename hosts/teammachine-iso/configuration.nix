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
    ../../modules/teammachine/desktop.nix
    ../../modules/teammachine/locale.nix
    ../../modules/teammachine/networking.nix
    ../../modules/teammachine/printer.nix
    ../../modules/teammachine/pxe-boot.nix
    ../../modules/teammachine/usbguard.nix
    ../../modules/teammachine/user-tools.nix
    ../../modules/teammachine/webcamstream.nix
  ];

  teammachine = {
    users.team = {
      languages = {
        c.enable = true;
        cpp.enable = true;
        python.enable = true;
        java.enable = true;
        kotlin.enable = false;
      };
      neovim.enable = true;
      ides.enable = true;
      ides.jetbrains.enable = true;
      submit.enable = true;
      games.enable = true;
      misc-packages.enable = true;
    };

    users.gehack = {
      neovim.enable = true;
    };
  };

  disabledModules = [ ../../modules/users.nix ];

  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;
  security.pam.services.su.requireWheel = true;
  programs.zsh.enable = true;

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../authorized_keys
    ../../fanout_pubkey
  ];

  users.users.team = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$GKsBsZ1X7y96QWFjU8j1x0$VaXm4KxSISIUZk49R7QQXc6opKxDKHOiXPA27zl6Zw8";
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
  };

  users.users.gehack = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$y$j9T$GKsBsZ1X7y96QWFjU8j1x0$VaXm4KxSISIUZk49R7QQXc6opKxDKHOiXPA27zl6Zw8";
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
    shell = pkgs.zsh;
  };

  # No greeter: GDM autologins the team user straight into GNOME.
  services.displayManager = {
    gdm.enable = lib.mkForce true;
    autoLogin = {
      enable = true;
      user = "team";
    };
  };
  # GNOME autologin races with getty on tty1 unless these are disabled.
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

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
