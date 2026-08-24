{
  config,
  lib,
  pkgs,
  ...
}:
let
  coreList = lib.concatMapStringsSep " " toString config.judgehost.cores;

  withCores = name: script: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      JUDGEHOST_CORES="${coreList}"
      ${builtins.readFile script}
    '';
  };

  tuneCpu = withCores "judgehost-tune-cpu" ./assets/tune-cpu.sh;
  checkCpu = withCores "judgehost-check-cpu" ./assets/check-cpu.sh;
in
{
  environment.systemPackages = [ checkCpu ];

  systemd.services.judgehost-tune-cpu = {
    description = "Lock CPU frequency, disable turbo, SMT siblings and efficiency cores";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Give intel_pstate and any thermal daemon time to settle before we pin
      # the governor read-only, matching tune_cpu.service in domjudge-scripts.
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      ExecStart = lib.getExe tuneCpu;
    };
  };
}
