{
  config,
  lib,
  pkgs,
  dj_url,
  ...
}:
let
  version = "bleeding";

  # Pinned by manifest digest so a re-pushed tag can never change what we judge on.
  # Refresh both fields together with:
  #   nix-prefetch-docker --image-name domjudge/judgehost --image-tag <version> \
  #     --arch amd64 --os linux
  image = pkgs.dockerTools.pullImage {
    imageName = "domjudge/judgehost";
    imageDigest = "sha256:18f6ba5edd334759056c78b3c5ebd199bce033b7333d8dcde30d9dff73733ab8";
    hash = "sha256-Y055eeleaOGvnAhuiZWdjjiyR8NVGfRjlKoZZYvWfz0=";
    finalImageName = "domjudge/judgehost";
    finalImageTag = version;
    os = "linux";
    arch = "amd64";
  };

  runUserBaseId = 62860;

  # Requires= as well as After=, so a failed prerequisite keeps the daemons from
  # registering under a wrong name or judging on an untuned CPU.
  ordering = [
    "judgehost-hostname.service"
    "judgehost-tune-cpu.service"
  ];

  container = core: lib.nameValuePair "judgehost-${toString core}" {
    imageFile = image;
    image = "domjudge/judgehost:${version}";
    autoStart = true;

    environment = {
      DAEMON_ID = toString core;
      RUN_USER_UID_GID = toString (runUserBaseId + core);
      DOMSERVER_BASEURL = "${dj_url}/";
      JUDGEDAEMON_USERNAME = "judgehost";
      CONTAINER_TIMEZONE = config.time.timeZone;
    };

    environmentFiles = [ config.sops.templates."judgehost.env".path ];

    # create_cgroups writes to the root cgroup.subtree_control, so the mount must be
    # writable and the host cgroup namespace must be visible. runguard additionally
    # chroots, bind-mounts /proc and unshares namespaces, which needs full privilege.
    volumes = [ "/sys/fs/cgroup:/sys/fs/cgroup" ];
    extraOptions = [
      "--privileged"
      "--cgroupns=host"
      "--network=host"
      "--uts=host"
    ];
  };

  unit = core: lib.nameValuePair "docker-judgehost-${toString core}" {
    after = ordering;
    requires = ordering;
    serviceConfig = {
      Slice = "judgehost.slice";
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce 3;
      # judgedaemon needs time to finish the judging it is holding, as upstream's
      # own domjudge-judgedaemon@.service allows.
      TimeoutStopSec = lib.mkForce 180;
    };
  };
in
{
  sops.secrets."judgehost.password" = { };

  sops.templates."judgehost.env".content = ''
    JUDGEDAEMON_PASSWORD=${config.sops.placeholder."judgehost.password"}
  '';

  virtualisation.oci-containers = {
    backend = "docker";
    containers = lib.listToAttrs (map container config.judgehost.cores);
  };

  systemd = {
    services = lib.listToAttrs (map unit config.judgehost.cores);

    # Keeps systemd realising the cpuset controller in the root cgroup, which
    # runguard needs to write cpuset.cpus and which a daemon-reload could otherwise
    # strip back out from under a running judging.
    slices.judgehost = {
      description = "DOMjudge judgedaemon containers";
      sliceConfig.AllowedCPUs = lib.concatMapStringsSep " " toString config.judgehost.cores;
    };
  };
}
