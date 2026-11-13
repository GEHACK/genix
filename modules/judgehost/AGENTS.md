Applies to `modules/judgehost/`, which is imported by `hosts/judgehost/configuration.nix`.

## Verify
- Evaluate `judgehost` with the root `## Verify` command.
- After touching `chroot.nix`, the image, the cores or the mounts: `nix eval --json .#nixosConfigurations.judgehost.config.virtualisation.oci-containers.containers --apply 'c: builtins.mapAttrs (_: v: v.volumes) c'`. It must show one `judgehost-<core>` per core, each with `…-domjudge-chroot:/chroot/domjudge:ro` and `…-domjudge-chroot/nix:/nix:ro`.

## Rules
- `judgehost.cores` (`default.nix`) drives five things: `isolcpus` (`boot.nix`, takes effect only after a reboot), `judgehost.slice` `AllowedCPUs`, `JUDGEHOST_CORES` in the tune script, one `judgehost-<core>` container each, and uid `62860+core` for `domjudge-run-<core>`. Change the list only, never one of those consumers.
- Judging cores must stay online after `judgehost-tune-cpu` offlines efficiency cores and SMT siblings, and they must sit on NUMA node 0; otherwise `assets/tune-cpu.sh` exits 1. Avoid core 0.
- `assets/tune-cpu.sh` also exits 1 if turbo or boost still reads enabled. `docker-judgehost-<core>` uses `Requires=` + `After=` on `judgehost-tune-cpu` and `judgehost-hostname`, so a failure there stops all judging. Do not weaken it to `Wants=`: untuned CPUs skew run times.
- Keep the `lib.mkForce` lines. `quiet.nix` turns off nix GC and auto-optimise, which `modules/nix.nix` turns on. `judgedaemon.nix` forces `Restart`, `RestartSec` and `TimeoutStopSec=180` so a judging in progress can finish.
- When changing the image, refresh `imageDigest` and `hash` together with the `nix-prefetch-docker` command in the `judgedaemon.nix` comment, and bump `version`. Never use a tag without a digest.
- Stock DOMjudge bind-mounts only `etc usr lib bin lib64` into each judging; the toolchain here lives under `/nix`, which the pinned `ghcr.io/gehack/judgehost` image is built to expose. Do not replace it with `domjudge/judgehost`.
- Keep both chroot volumes `:ro` (`${chroot}:/chroot/domjudge`, `${chroot}/nix:/nix`). The containers run `--privileged` with host cgroup, network and UTS namespaces.

## Traps
- `chroot.nix` puts `lib.attrValues contestToolchain` into a `buildEnv` linking only `/bin`. Every attr in `contestToolchain` (`modules/teammachine/languages.nix`) must therefore be a derivation, and a tool is reachable in the chroot only through its `bin/`.
- `domjudge-run-<core>` users exist only in the chroot's `etc/passwd` (written by `chroot.nix`), never on the host. Do not add them to `users.users`.
- `networking.hostName = ""` is deliberate. `judgehost-hostname` sets `judge-<last 6 MAC hex>` because DOMjudge needs a unique name per machine. It fails when no physical NIC is present.
- `judgehost.password` reaches the containers through the `judgehost.env` sops template, which has no `restartUnits`. After rotating it, the containers must be restarted.
