{ config, lib, ... }:
{
  imports = [
    ./boot.nix
    ./cpu-tuning.nix
    ./judgedaemon.nix
    ./networking.nix
    ./quiet.nix
  ];

  options.judgehost.cores = lib.mkOption {
    type = lib.types.listOf lib.types.ints.unsigned;
    apply = lib.unique;
    default = [ 2 ];
    example = [
      2
      3
      4
    ];
    description = ''
      CPU cores dedicated to judging. One judgedaemon container runs per core, and
      DOMjudge pins each submission to its core through runguard's cpuset.

      A core must still be online once judgehost-tune-cpu has offlined SMT siblings
      and efficiency cores, and it must sit on NUMA node 0 because runguard hardcodes
      cpuset.mems to 0. Both are asserted at boot. Avoid core 0, which the kernel
      cannot offline and which handles most interrupts.
    '';
  };

  config.assertions = [
    {
      assertion = config.judgehost.cores != [ ];
      message = "judgehost.cores must name at least one core to judge on.";
    }
  ];
}
