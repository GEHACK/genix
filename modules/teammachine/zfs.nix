{ config, pkgs, lib, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wipe-user-data" ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "Error: must be run as root" >&2
        exit 1
      fi
      echo "Setting wipe flag on zroot..."
      # Use the absolute path from the package
      ${pkgs.zfs}/bin/zfs set user:wipe-on-reboot=true zroot
      echo "Wipe armed! Reboot to execute."
    '')
  ];

  boot.initrd.systemd.services.rollback-on-boot = {
    description = "Rollback ZFS datasets if wipe flag is set";
    wantedBy = [ "initrd-root-device.target" ];
    after = [ "zfs-import-zroot.service" ]; 
    before = [ "sysroot.mount" ];           
    path = [ pkgs.zfs ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      FLAG=$(zfs get -H -o value user:wipe-on-reboot zroot || echo "false")
      
      if [ "$FLAG" = "true" ]; then
        echo "Wipe flag detected! Purging root and home..."
        # -R ensures we destroy any snapshots created since 'blank'
        zfs rollback -rR zroot/root@blank
        zfs rollback -rR zroot/home@blank
        zfs set user:wipe-on-reboot=false zroot
        echo "Purge complete."
      else
        echo "No wipe flag detected. Proceeding with normal boot."
      fi
    '';
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # Necessary for Homemanager
  systemd.tmpfiles.rules = [
    "d /home/team 0700 team users -"
    "d /home/gehack 0700 gehack users -"
  ]; 

  fileSystems."/etc/sops" = {
    device = "/persist/etc/sops";
    options = [ "bind" ];
    neededForBoot = true; 
  };

  fileSystems."/persist".neededForBoot = true;

  networking.hostId = builtins.substring 0 8 (
    builtins.hashString "sha256" config.networking.hostName
  );
}