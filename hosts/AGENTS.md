Applies to `hosts/*/` (all six hosts) and the host-facing rules of `modules/cds/` and `modules/utility/`.

## Verify
- Evaluate every host you touched with the root `## Verify` command; it also works for `teammachine-iso`.
- After editing a `disko.nix`: `nix eval --json .#nixosConfigurations.<host>.config.disko.devices.disk --apply 'd: builtins.mapAttrs (_: v: v.device) d'` and compare with the table.

## Rules
- `disko.nix` wipes its devices on install; a wrong `device` destroys the wrong disk. There is no `hardware-configuration.nix`: hardware facts are hand-written, never generate one.

| Host | Device | Root |
|---|---|---|
| teammachine | `/dev/nvme0n1` | `100G` |
| cds | `/dev/nvme0n1` | `450G` |
| judgehost | `/dev/vda` | `450G` |
| utility | `/dev/nvme0n1` | `100%` of `imageSize = "16G"` |
| geproxy | `/dev/sda` + `/dev/sdb` | `100%` on mdraid1 `root_raid` |

- Keep the fixed root sizes: the rest of the disk stays unallocated on purpose, for faster imaging.
- geproxy: ESP mountpoints `/boot` (sda) and `/boot-fallback` (sdb) must match `mirroredBoots` in `modules/geproxy/boot.nix`; change both or neither.
- Every host except the ISO needs the shared age key at `/etc/sops/hostkey` (`modules/sops.nix`). Nothing in the repo provisions it (`modules/image.nix` only passes it into the utility image), and without it no secret decrypts, including the `neededForUsers` `hashed-password`.
- Keep hostname `cds`: geproxy's default upstream is `cds.local` (`modules/geproxy/cds.nix`), announced by Avahi (`modules/cds/mdns.nix`). teammachine and judgehost get `networking.hostName` from their role `networking.nix`; do not set it in their host files.
- `fanout_pubkey` (geproxy's deploy relay) is a root key on teammachine, utility, cds and the ISO only; judgehost and geproxy lack it. A new host deployed through fanout needs it in its role `users.nix`.
- `services.loomd.label` (turns on loomd and its `loom.authToken` secret) and `monitoring.enable` are per-host: set in `hosts/judgehost` and `hosts/utility`, in `modules/teammachine/station.nix` for teammachine, label only on cds. `geproxy.monitoring.enable` is the metrics receiver, not this exporter.
- utility: leave `utility.presentation.contestId` at `__CONTEST__` (geproxy's `cds` site substitutes `contest_id` via `rewriteContest`), and keep `modules/utility/power.nix` plus the dconf idle settings in `modules/utility/desktop.nix`: the projector must never sleep or lock.
- judgehost and utility import `modules/teammachine/{geproxy,netboot}.nix` by path; netboot reads `teammachine.geproxy.*`, so keep both imports.

## Traps
- `teammachine-iso` is a fork: no `disko.nix`, and `disabledModules = [ ../../modules/users.nix ]` with users re-declared inline using a literal `hashedPassword`. Never copy that into a real host; they use the sops `hashed-password`.
- The ISO imports nine `modules/teammachine/*.nix` files by path, not `modules/teammachine/default.nix`: new teammachine files do not reach it and renames break it.
