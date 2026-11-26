{
  config,
  lib,
  pkgs,
  dj_url,
  contestToolchain,
  ...
}:

let
  version = "bleeding-gehack.1";

  runUid = core: 62860 + core;
  runUser = core: "domjudge-run-${toString core}";
  serviceName = core: "domjudge-judgehost-${toString core}";
  stateDir = core: "/var/lib/${serviceName core}";
  runtimeDir = core: "/run/${serviceName core}";
  prepareServiceName = core: "${serviceName core}-prepare";

  domjudgeSrc = pkgs.fetchFromGitHub {
    owner = "DOMjudge";
    repo = "domjudge";
    rev = "main";
    hash = "sha256-P0Uuj1cAsfyn2hTRzI/VfvCN2Hj5SG/e4r++yOH1OOk=";
  };

  domjudgeJudgehost = pkgs.stdenv.mkDerivation {
    pname = "domjudge-judgehost";
    inherit version;
    src = domjudgeSrc;

    nativeBuildInputs = with pkgs; [
      gnumake
      pkg-config
      autoreconfHook
      autoconf-archive
    ];

    buildInputs =
      with pkgs;
      [
        php
        php.packages.composer
        libxml2
        libzip
        curl
        openssl
        zlib
        libcgroup
      ];

    configurePhase = ''
      runHook preConfigure
      ./configure \
        --prefix="$out" \
        --with-baseurl="${dj_url}" \
        --with-domjudge-user=domjudge \
        --with-webserver-group=www-data
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      export LIBRARY_PATH="${pkgs.glibc.static}/lib''${LIBRARY_PATH:+:$LIBRARY_PATH}"
      make judgehost
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      make install-judgehost
      touch $out/judgehost/etc/restapi.secret
      runHook postInstall
    '';
  };

  chroot = pkgs.callPackage ./chroot.nix {
    inherit contestToolchain;
    runUsers = lib.listToAttrs (
      map
        (core: lib.nameValuePair (runUser core) (runUid core))
        config.judgehost.cores
    );
  };

  prepareServiceFor = core:
    let
      name = serviceName core;
      prepareName = prepareServiceName core;
      state = stateDir core;
    in
    lib.nameValuePair prepareName {
      description = "Prepare ${name} installation";
      before = [ "${name}.service" ];
      requiredBy = [ "${name}.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;

        ExecStart = pkgs.writeShellScript "prepare-${name}" ''
          set -eu

          state=${lib.escapeShellArg state}
          install=${lib.escapeShellArg "${domjudgeJudgehost}"}

          # Create the writable copy so bind-mount destinations exist before
          # systemd sets up the judgehost service's mount namespace.
          mkdir -p "$state"

          # Writable bind-mount sources.
          mkdir -p "$state/log" "$state/run" "$state/judgings"
          chown domjudge:domjudge "$state/log" "$state/run" "$state/judgings"

          # Re-install the sudoers file
          install -D -oroot -groot -m0400 ${domjudgeJudgehost}/judgehost/etc/sudoers-domjudge /etc/sudoers.d/domjudge
          # Fix the `/bin` path for nixos
          sed -i 's|NOPASSWD: /bin/cp|NOPASSWD: /run/current-system/sw/bin/cp|' /etc/sudoers.d/domjudge
          sed -i 's|NOPASSWD: /bin/chmod|NOPASSWD: /run/current-system/sw/bin/chmod|' /etc/sudoers.d/domjudge
          sed -i 's|NOPASSWD: /bin/chown|NOPASSWD: /run/current-system/sw/bin/chown|' /etc/sudoers.d/domjudge
          sed -i 's|NOPASSWD: /bin/mount|NOPASSWD: ${config.security.wrapperDir}/mount|' /etc/sudoers.d/domjudge
          sed -i 's|NOPASSWD: /bin/umount|NOPASSWD: ${config.security.wrapperDir}/umount|' /etc/sudoers.d/domjudge
        '';
      };
    };

  serviceFor = core:
    let
      n = toString core;
      name = serviceName core;
      prepareName = prepareServiceName core;
      state = stateDir core;
      runtime = runtimeDir core;
    in
    lib.nameValuePair name {
      description = "DOMjudge judgehost ${n}";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      requires = [
        "${prepareName}.service"
        "judgehost-hostname.service"
        "judgehost-tune-cpu.service"
        "domjudge-create-cgroups.service"
      ];
      after = [
        "network-online.target"
        "${prepareName}.service"
        "judgehost-hostname.service"
        "judgehost-tune-cpu.service"
        "domjudge-create-cgroups.service"
      ];


      serviceConfig = {
        Type = "simple";
        Slice = "judgehost.slice";
        
        # Needs a custom `PATH=` as the `wrapperDir` breaks in the nix `path=` syntax.
        Environment = [
          "DJ_SUBDIRMOUNTS=nix"
          "PATH=${config.security.wrapperDir}:/bin:/run/current-system/sw/bin"
        ];

        RuntimeDirectory = name;
        RuntimeDirectoryMode = "0700";

        # We bind mount restapi secret the writable state directories over the nix store.
        BindPaths = [
          "${config.sops.templates."judgehost-restapi".path}:${domjudgeJudgehost}/judgehost/etc/restapi.secret"
          "${state}/log:${domjudgeJudgehost}/judgehost/log"
          "${state}/run:${domjudgeJudgehost}/judgehost/run"
          "${state}/judgings:${domjudgeJudgehost}/judgehost/judgings"
        ];

        WorkingDirectory = domjudgeJudgehost;
        ExecStart = "${domjudgeJudgehost}/judgehost/bin/judgedaemon -n ${n}";
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 180;

        User = "domjudge";
        Group = "domjudge";

        NoNewPrivileges = false;
        PrivateUsers = false;
        ProtectControlGroups = false;
        ProtectKernelTunables = false;

        BindReadOnlyPaths = [ "${chroot}:/chroot/domjudge" ];
      };
    };

in
{
  security.sudo = {
    extraConfig = ''
      @includedir /etc/sudoers.d
    '';
    enable = true;
  };
  sops.secrets."judgehost.password" = { };

  # Template the `restapi.secret` such that it does not end up in the nix store.
  sops.templates."judgehost-restapi" = {
    owner = "domjudge";
    group = "domjudge";
    mode = "0600";
    content = ''
      default ${dj_url}/api judgehost ${config.sops.placeholder."judgehost.password"}
    '';
  };

  users.groups = {
    domjudge-run = { };
    domjudge = { };
  };

  users.users =
    lib.listToAttrs (
      map
        (core:
          lib.nameValuePair (runUser core) {
            isSystemUser = true;
            group = "domjudge-run";
            uid = runUid core;
            home = "/var/empty";
            createHome = false;
            shell = pkgs.shadow;
          })
        config.judgehost.cores
    )
    // {
      domjudge = {
        isSystemUser = true;
        group = "domjudge";
        home = "/var/empty";
        createHome = false;
        shell = pkgs.shadow;
      };
    };

  systemd.services =
    lib.listToAttrs (
      map prepareServiceFor config.judgehost.cores
    )
    // lib.listToAttrs (
      map serviceFor config.judgehost.cores
    )
    // {
      domjudge-create-cgroups = {
        description = "Create DOMjudge cgroups";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.gawk ];
        before = map
          (core: "${serviceName core}.service")
          config.judgehost.cores;

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${domjudgeJudgehost}/judgehost/bin/create_cgroups";
        };
      };
    };

  systemd.slices.judgehost = {
    description = "DOMjudge native judgehost services";
    sliceConfig.AllowedCPUs =
      lib.concatMapStringsSep " " toString config.judgehost.cores;
  };
}
