{
  config,
  lib,
  pkgs,
  runtimes_host,
  ...
}:
let
  cfg = config.runtimes;

  # Directory with `deploy_key` and `upload_token`, set by scripts/build-runtimes-iso.sh
  # after decrypting both from secrets.yaml. Never committed: genix is public, and the
  # deploy key reads the private problem set.
  secretsDir = builtins.getEnv "RUNTIMES_SECRETS";
  secret = name: if secretsDir == "" then null else /. + "${secretsDir}/${name}";

  # The python env, not the `bt` wrapper: the wrapper pulls in a full TeX Live for
  # statements, which time_limit never touches.
  bt = pkgs.bapctools.env;

  # Compilers and interpreters the contest languages.yaml calls by name. These must be
  # the same packages as users/team/languages.nix, so the ISO measures exactly what
  # teams compile with; change both together.
  toolchains = with pkgs; [
    gcc
    gnumake
    pypy3
    jdk21
    kotlin
  ];

  tuneCpu = pkgs.writeShellApplication {
    name = "runtimes-tune-cpu";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # No core is set aside for judging here, so the judgehost per-core checks are no-ops.
      JUDGEHOST_CORES=""
      ${builtins.readFile ../judgehost/assets/tune-cpu.sh}
    '';
  };

  # Runs under bt's interpreter so it can read the BAPCtools version.
  report = pkgs.writeShellScriptBin "runtimes-report" ''
    exec ${bt}/bin/python3 ${./assets/report.py} "$@"
  '';

  run = pkgs.writeShellApplication {
    name = "runtimes-run";
    runtimeInputs = [
      bt
      tuneCpu
      report
      pkgs.age
      pkgs.coreutils
      pkgs.curl
      pkgs.git
      pkgs.gnugrep
      pkgs.gzip
      pkgs.openssh
      pkgs.util-linux
    ]
    ++ toolchains;
    text = ''
      REPO=${lib.escapeShellArg cfg.repo}
      REF=${lib.escapeShellArg (if cfg.ref == null then "" else cfg.ref)}
      CONTEST_DIR=${lib.escapeShellArg cfg.contestDir}
      DEPLOY_KEY=${lib.optionalString (cfg.deployKey != null) "${cfg.deployKey}"}
      UPLOAD_TOKEN=${lib.optionalString (cfg.uploadToken != null) "${cfg.uploadToken}"}
      RECIPIENTS=${cfg.recipients}
      KNOWN_HOSTS=${cfg.knownHosts}
      JOBS=${toString cfg.jobs}
      REPORT_URL=${lib.escapeShellArg cfg.reportUrl}
      ${builtins.readFile ./assets/run.sh}
    '';
  };
in
{
  options.runtimes = {
    repo = lib.mkOption {
      type = lib.types.str;
      default = "ssh://forgejo@forgejo.ragnargrootkoerkamp.nl/bapc/2026.git";
      description = "Git repository of the problem set, cloned over SSH at boot.";
    };

    ref = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "main";
      description = "Branch or tag to measure; null takes the repository's default branch.";
    };

    contestDir = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Directory holding contest.yaml, relative to the repository root.";
    };

    deployKey = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = secret "deploy_key";
      defaultText = lib.literalExpression ''$RUNTIMES_SECRETS/deploy_key'';
      description = ''
        Private SSH key with read access to `repo`, typically a deploy key whose public
        half is `assets/deploy_key.pub`. It ends up in the ISO and in the build
        machine's store, so never push the ISO to a public binary cache.
      '';
    };

    uploadToken = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = secret "upload_token";
      defaultText = lib.literalExpression ''$RUNTIMES_SECRETS/upload_token'';
      description = ''
        Bearer token the receiver requires on uploads; its SHA-256 is
        `assets/upload_token.sha256`. Rotate both if a stick goes missing.
      '';
    };

    recipients = lib.mkOption {
      type = lib.types.path;
      default = ./assets/report_recipients.txt;
      description = "age recipients the report is encrypted to before upload; only they can read it.";
    };

    knownHosts = lib.mkOption {
      type = lib.types.path;
      default = ./assets/known_hosts;
      description = "Pinned SSH host keys of the server hosting `repo`.";
    };

    jobs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = ''
        Submissions bt runs at once. One matches a judgehost, which judges one
        submission per core; more finishes sooner but lets runs contend for cache
        and memory bandwidth, inflating the measured times.
      '';
    };

    reportUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://${runtimes_host}/api/reports";
      description = "Endpoint the JSON report is POSTed to. Only ever contacted over verified TLS.";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.deployKey != null && cfg.uploadToken != null;
        message = "runtimes-iso needs the deploy key and upload token; build it with scripts/build-runtimes-iso.sh.";
      }
      {
        assertion = lib.hasPrefix "https://" cfg.reportUrl;
        message = "runtimes.reportUrl must be an https:// URL; reports are never sent in the clear.";
      }
    ];

    environment.systemPackages = [
      bt
      report
      tuneCpu
    ]
    ++ toolchains;

    # Nobody logs in on tty1: it shows the run, then the results. Alt+F2 still has a getty.
    systemd.services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;

      runtimes = {
        description = "Measure problem set runtimes and report them";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-user-sessions.service" ];
        conflicts = [ "getty@tty1.service" ];

        environment = {
          TERM = "linux";
          HOME = "/root";
          # As on the team machine: Java and Kotlin find JDK 21, and `-static` links
          # against the static glibc the team machine's mygcc/mygpp pass with -L.
          JAVA_HOME = "${pkgs.jdk21.home}";
          LIBRARY_PATH = "${pkgs.glibc.static}/lib";
        };

        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe run;

          TTYPath = "/dev/tty1";
          TTYReset = true;
          TTYVHangup = true;
          StandardInput = "null";
          StandardOutput = "tty";
          StandardError = "tty";
        };
      };
    };

    # The results stay on screen for whoever comes back to the machine.
    boot.kernelParams = [ "consoleblank=0" ];
  };
}
