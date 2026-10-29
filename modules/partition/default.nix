{
  config,
  lib,
  pkgs,
  ...
}:
let
  device = "/dev/disk/by-label/teammachine";

  installUki = pkgs.writeShellApplication {
    name = "install-teammachine-uki";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      toplevel="$1"
      boot="''${2:-/boot}"
      mkdir -p "$boot"
      ${pkgs.systemdUkify}/lib/systemd/ukify build \
        --linux "$toplevel/kernel" \
        --initrd "$toplevel/initrd" \
        --cmdline "init=$toplevel/init $(cat "$toplevel/kernel-params")" \
        --stub ${pkgs.systemd}/lib/systemd/boot/efi/linux${pkgs.stdenv.hostPlatform.efiArch}.efi.stub \
        --os-release "@$toplevel/etc/os-release" \
        --output "$boot/teammachine.efi.new"
      mv "$boot/teammachine.efi.new" "$boot/teammachine.efi"
    '';
  };

  mountTopLevel = ''
    top=/run/teammachine-btrfs
    mkdir -p "$top"
    mount -o subvolid=5 ${device} "$top"
    trap 'umount "$top"' EXIT
  '';

  reset = pkgs.writeShellApplication {
    name = "teammachine-reset";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.findutils
      pkgs.util-linux
      pkgs.systemd
    ];
    text = ''
      ${mountTopLevel}
      if [ ! -e "$top/snapshots/root-pristine" ]; then
        echo "teammachine-reset: no pristine snapshot" >&2
        exit 1
      fi
      if [ -e "$top/root-previous" ]; then
        btrfs subvolume delete --recursive "$top/root-previous"
      fi
      mv "$top/root" "$top/root-previous"
      btrfs subvolume snapshot "$top/snapshots/root-pristine" "$top/root"
      find "$top/root" -inum 2 -type d -empty -delete
      systemctl reboot
    '';
  };

  subvolume = name: {
    inherit device;
    fsType = "btrfs";
    options = [
      "subvol=${name}"
      "compress=zstd"
    ];
  };
in
{
  disko.enableConfig = false;

  fileSystems = {
    "/" = subvolume "root" // {
      autoResize = true;
    };
    "/nix" = subvolume "nix";
    "/boot" = subvolume "boot";
    "/persist" = subvolume "persist" // {
      neededForBoot = true;
    };
  };

  boot.loader = {
    grub.enable = lib.mkForce false;
    external = {
      enable = true;
      installHook = lib.getExe installUki;
    };
  };

  boot.kernelParams = [ "systemd.gpt_auto=0" ];

  boot.postBootCommands = ''
    if [ -f /nix/nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < /nix/nix-path-registration
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      touch /etc/NIXOS
      rm /nix/nix-path-registration
    fi
  '';

  systemd.services.teammachine-pristine-snapshot = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    path = [
      pkgs.btrfs-progs
      pkgs.util-linux
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${mountTopLevel}
      if [ ! -e "$top/snapshots/root-pristine" ]; then
        btrfs subvolume snapshot -r "$top/root" "$top/snapshots/root-pristine"
      fi
    '';
  };

  environment.systemPackages = [ reset ];

  sops.age.keyFile = lib.mkForce "/persist/sops/hostkey";

  services.openssh.hostKeys = [
    {
      path = "/persist/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  system.build.partitionImage =
    let
      closure = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
    in
    pkgs.runCommand "teammachine-image"
      {
        nativeBuildInputs = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.zstd
        ];
      }
      ''
        mkdir -p fs/root/nix fs/root/boot fs/root/persist fs/nix/store fs/boot fs/persist fs/snapshots $out
        xargs -I % cp -a --reflink=auto % -t fs/nix/store < ${closure}/store-paths
        hardlink fs/nix/store
        cp ${closure}/registration fs/nix/nix-path-registration
        ${lib.getExe installUki} ${config.system.build.toplevel} fs/boot
        touch teammachine.img
        unshare --map-root-user mkfs.btrfs -L teammachine -r fs -u root -u nix -u boot -u persist --shrink teammachine.img
        zstd -T$NIX_BUILD_CORES -19 --long=27 teammachine.img -o $out/teammachine.img.zst
      '';
}
