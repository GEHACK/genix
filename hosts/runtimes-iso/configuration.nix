{ modulesPath, lib, ... }:
{
  # Flash, plug into the machine under test with a network cable, boot, walk away.
  # The ISO runs `bt time_limit` on the problem set with the CPU tuned like a
  # judgehost (optionally first on stock settings) and uploads the results over HTTPS.
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    # The machine under test is unknown hardware, so ship every storage and NIC driver.
    (modulesPath + "/profiles/all-hardware.nix")
    ../../modules/nix.nix
    ../../modules/security.nix
    ../../modules/ssh.nix
    ../../modules/judgehost/quiet.nix
    ../../modules/runtimes-iso
  ];

  # quiet.nix ignores the power key so a judgehost survives a bump; here pressing it
  # is how the operator is told to shut down once the results are in.
  services.logind.settings.Login.HandlePowerKey = lib.mkForce "poweroff";

  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];

  image.fileName = lib.mkForce "gehack-runtimes.iso";
  isoImage = {
    volumeID = lib.mkForce "GEHACK_RUNTIMES";
    makeEfiBootable = true;
    makeUsbBootable = true;
    squashfsCompression = "zstd -Xcompression-level 6";
  };

  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;

  networking.hostName = "gehack-runtimes";
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
}
