# genix

NixOS flake that declares every machine at a GEHACK programming contest; a machine's whole state is one `nixosConfigurations` attribute.

## Hosts

All outputs are `x86_64-linux`. `flake.nix` is the only composition point: a `<host>Modules` list → `hosts/<host>/configuration.nix` → `modules/` (base, every host) + `modules/<role>/`.

| Host | Purpose | Build attr |
|---|---|---|
| `teammachine` | Contestant laptop, hostname `team`: GNOME, loom-greeter, locked-down `team` user | `nixosConfigurations.teammachine.config.system.build.toplevel` |
| `geproxy` | Gateway: bridges, dnsmasq, nftables, Caddy, loom, imaged, deploy fanout | `nixosConfigurations.geproxy.config.system.build.toplevel` |
| `judgehost` | DOMjudge judgedaemons on isolated cores | `nixosConfigurations.judgehost.config.system.build.toplevel` |
| `cds` | ICPC Contest Data Server container | `nixosConfigurations.cds.config.system.build.toplevel` |
| `utility` | Admin-desk machine: scoreboard presentation and balloons | `nixosConfigurations.utility.config.system.build.toplevel` |
| `teammachine-iso` | Public live ISO, a fork of `teammachine` | `packages.x86_64-linux.teammachine-iso` |

## Verify

There is no formatter, linter or devShell, and CI only publishes the `chroot/` image. Building is the only check. Build every host a change can reach; a change under `modules/*.nix` reaches all six.

```bash
nix build .#<build attr from the table>
nix build .#checks.x86_64-linux.geproxy-network
nix build .#checks.x86_64-linux.teammachine-rdp
nix build .#packages.x86_64-linux.teammachine-vm && ./result/bin/run-*-vm
```

- Run `geproxy-network` after touching `modules/geproxy/network/`, and `teammachine-rdp` after touching `modules/teammachine/remote-desktop.nix`.
- New files must be `git add`ed (or `git add -N`) before Nix sees them.
- The VM is for behaviour a build cannot show; it forwards ssh to host port 2222 (`ssh -p 2222 root@localhost`).
- Without an `x86_64-linux` builder (macOS), `nix build` cannot realise these. Evaluate instead, about 40 s per host:
  `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
  It catches option, type and assertion errors, but not build-time checks such as the nftables `checkRuleset`. The two `checks` cannot be evaluated there at all.

## Change rules

- **New module**: add it to the `imports` list of `modules/<role>/default.nix` (`modules/default.nix` for base modules), or it is never loaded. Two files must stay out: `modules/judgehost/chroot.nix` is a `callPackage`d package, and `modules/image.nix` is wired from `flake.nix` for utility only.
- **New host**: `hosts/<h>/configuration.nix` and `hosts/<h>/disko.nix`, then in `flake.nix` a `<h>Modules` list, a `nixosSystem`, the `nixosConfigurations` entry and `packages.x86_64-linux.<h>`.
- **Feature modules are opt-in**: `options.<role>.<feature>.enable = lib.mkEnableOption "…";` with `config = lib.mkIf cfg.enable { … };`, switched on in the host file. Host files hold hardware facts and toggles, no logic.
- **Contest facts are `specialArgs` in `flake.nix`, not options**: `dj_url`, `loom_url`, `geproxy_ip`, `contest_subnet`, `admin_ip`, `admin_subnet`, `imaged_port`, `cds_port`, `contest_id`. Changing `contest_id` rebuilds geproxy and cds. `cds_port` only sets the URLs that geproxy and utility use; the CDS itself hardcodes 8443 in `modules/cds/cds.nix`.
- **Firewall is nftables only; never write iptables rules.** teammachine, geproxy and the ISO set `networking.firewall.enable = false`, so `networking.firewall.*` options do nothing there. judgehost, cds and utility run the stock NixOS firewall.
- **Secrets only through sops**: declare `sops.secrets.<name>` in the module that uses it and pass `config.sops.secrets.<name>.path`. Combine several values with `sops.templates` and `config.sops.placeholder`. Never put a secret in Nix as plaintext, and never decrypt or print `secrets.yaml`.
- **Contest languages only via `pkgs.contestToolchain`** (`modules/teammachine/languages.nix`). The judgehost builds its judging chroot from the teammachine's evaluated toolchain, so a plain `pkgs.<compiler>` silently differs from what the judge runs.
- **`users/` holds home-manager modules only.** System users live in `modules/users.nix` and `modules/<role>/users.nix`.
- **`flake.nix` must stay a plain attrset with a literal `nixConfig`**: `modules/geproxy/build-host.nix` reads it with `import ../../flake.nix`.
- **Leave as is**: `system.stateVersion = "25.11"` on every host (nixpkgs is 26.05, intentional), and inputs without `inputs.nixpkgs.follows` (adding it rebuilds that input against a different nixpkgs).
- **`scripts/*.sh`**: check an edit with `bash -n scripts/<file>` only. Never execute a script to test it.
- `README.md` is stale in specifics (key holders, file paths, the teammachine firewall). Trust the source.
- Commits follow Conventional Commits without a scope (`feat:`, `fix:`, `chore:`); branches are `<type>/<kebab-slug>`.

## Never without explicit human approval

- `nixos-rebuild switch`, `boot` or `test`, and anything with `--target-host`.
- `scripts/install.sh`: its remote mode switches a live host without a prompt.
- `scripts/format.sh`: it wipes disks with `disko --mode destroy,format,mount`. It is not a code formatter.
- `scripts/nixos-anywhere.sh`, `nixos-anywhere` and `disko`.
- `nix flake update`, or any other change to `flake.lock`.
- Editing `secrets.yaml` (only `sops secrets.yaml` keeps its MAC valid), `.sops.yaml` or `fanout_pubkey`.
- Editing `authorized_keys` or running `scripts/update_keys.sh`: the file is generated from GitHub, and the script stages it in git.
- ssh or any other action against a contest machine, and pushing to `main` (CI then publishes an image).

## Directory guides

- Before editing `hosts/`, read `hosts/AGENTS.md`.
- Before editing `modules/geproxy/` (including `network/`), read `modules/geproxy/AGENTS.md`.
- Before editing `modules/teammachine/`, read `modules/teammachine/AGENTS.md`.
- Before editing `modules/judgehost/`, read `modules/judgehost/AGENTS.md`.
- Before editing `users/`, read `users/AGENTS.md`.
- Before editing `tests/`, read `tests/AGENTS.md`.
- Before editing `docs/`, read `docs/AGENTS.md`.
- Before editing `chroot/`, read `chroot/AGENTS.md`.
