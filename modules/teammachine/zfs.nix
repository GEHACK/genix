{ config, pkgs, lib, ... }: 

{ 
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.package = pkgs.zfs;

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wipe-user-data" ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "Error: must be run as root (use sudo)" >&2
        exit 1
      fi
      
      echo "Arming the system for a total state wipe..."
      ${pkgs.zfs}/bin/zfs set user:wipe-on-reboot=true zroot
      
      echo "Wipe armed! Reboot to execute."
    '')
  ];

  boot.initrd.postDeviceCommands = lib.mkAfter ''
  # Make sure the pool is imported
  ${pkgs.zfs}/bin/zpool import -f zroot || true

  if [ "$(${pkgs.zfs}/bin/zfs get -H -o value user:wipe-on-reboot zroot)" = "true" ]; then
    echo "Wipe flag detected! Purging root and home datasets..."
    ${pkgs.zfs}/bin/zfs rollback -r zroot/root@blank
    ${pkgs.zfs}/bin/zfs rollback -r zroot/home@blank
    ${pkgs.zfs}/bin/zfs set user:wipe-on-reboot=false zroot
    echo "Purge complete."
  fi
'';

  environment.persistence."/persist" = {
    hideMounts = true; 
    
    directories = [
      "/etc/sops"  
    ];
    
    files = [ 
      "/etc/ssh/ssh_host_ed25519_key" 
      "/etc/ssh/ssh_host_ed25519_key.pub" 
      "/etc/ssh/ssh_host_rsa_key" 
      "/etc/ssh/ssh_host_rsa_key.pub" 
    ];
  };

  systemd.tmpfiles.rules = [
    "d /home/team 0700 team users -"
    "d /home/gehack 0700 gehack users -"
  ]; 
  
  fileSystems."/persist".neededForBoot = true;

  networking.hostId = builtins.substring 0 8 (
    builtins.hashString "sha256" config.networking.hostName
  );
  boot.zfs.forceImportRoot = true;
}

