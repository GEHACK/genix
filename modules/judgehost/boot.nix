{ config, lib, ... }:
{
  # domjudge-scripts additionally sets cgroup_enable=memory, swapaccount=1,
  # apparmor=0 and systemd.unified_cgroup_hierarchy=0. None of those belong here:
  # the first two are cgroup v1 knobs that DOMjudge 9 no longer reads, AppArmor is
  # already disabled, and systemd 256+ refuses to boot under a cgroup v1 hierarchy.
  boot = {
    kernelParams = [
      "isolcpus=${lib.concatMapStringsSep "," toString config.judgehost.cores}"
    ];

    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        devices = [ "nodev" ];
      };
    };
  };
}
