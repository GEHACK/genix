# GEHACK NixOS Infrastructure

NixOS flake-based infrastructure-as-code for the GEHACK competitive programming competitions like FPC, EAPC and EUC26. This repository manages fully declarative system configurations for contest workstations, a network router/firewall, and a scoreboard kiosk — all defined in Nix with no imperative package management.

---

## Machines

### `teammachine` — Contest Workstation

The primary machine used by contestants during a competition. Available for both x86_64 (`teammachine`) and aarch64 (`teammachine_arm`).

**Users:**
- `gehack` — admin user with sudo, zsh shell, SSH key access
- `team` — restricted contest user; all nix commands blocked, Firefox locked to contest homepage, WiFi and Bluetooth disabled at the kernel module level (`iwlwifi`, `btusb`)

**Contest toolchains** (via `modules/teammachine/languages.nix`):
- `mygcc` — C with `-std=gnu17 -O2 -static`
- `mygpp` — C++ with `-std=gnu++20 -O2 -static`
- `mypython` — PyPy3
- `myjavac` — Java 21
- `mykotlinc` — Kotlin

**IDEs and editors:**
- PyCharm (FHS-wrapped for Python path compatibility)
- IntelliJ IDEA
- CLion
- Eclipse
- NetBeans
- Code::Blocks
- Geany
- Vim, Neovim, Emacs, Nano
- gedit

**Other features:**
- GNOME desktop, no GDM — uses [`loom-greeter`](https://github.com/luukblankenstijn/loom) via greetd (from the loom flake input)
- [`loomd`](https://github.com/luukblankenstijn/loom) service connects to the Loom contest platform for team management
- [`submit`](https://github.com/DOMjudge/DOMjudge) CLI pre-configured to submit to DOMjudge (URL set via `dj_url` specialArgs in `flake.nix`)
- [Devdocs](github.com/GEHACK/devdocs) served locally via Docker at `http://docs` (port 80)
- Printing via CUPS, pre-configured to IPP printer on geproxy (`10.0.0.1:631`)
- Webcam HTTP stream on port 8080 via VLC (`webcamstream.nix`) - by default disabled
- `pxe-reboot` command — sets EFI next-boot to the PXE/IPv4 entry and reboots for imaged deployment
- USBGuard enabled (currently allows all present devices)
- Firewall drops all traffic to `contest_subnet` except to/from `judge_ip`
- Sleep, hibernate, and suspend are all disabled

---

### `geproxy` — Router / Firewall

Acts as the contest network router. Runs on hardware with multiple NICs bridged into two networks.

**Network layout:**

| Bridge | Interface(s) | Subnet | Purpose |
|--------|-------------|--------|---------|
| `br-admin` | `eno2` | 10.0.1.0/24 | Admin / organiser network |
| `br-contest` | `eno3–eno6` | 10.0.0.0/24 | Contest / team network |

- `wlp6s0` and `eno1` use DHCP for upstream connectivity
- dnsmasq provides DHCP and DNS on both bridges
- Contest DNS resolves `judge.gehack.nl`, `loom.gehack.nl`, `cds.gehack.nl`, `imaged.gehack.nl`, and `docs.gehack.nl` to `10.0.0.1`
- PXE/imaged boot configured for BIOS and EFI clients via dnsmasq `dhcp-boot`

**imaged** runs as native NixOS services (`imaged-server` + `imaged-tftp`) for disk imaging and deployment of teammachines over the contest network. The web UI is accessible at `imaged.gehack.nl` via Traefik; PXE clients use `http://10.0.0.1:8080/boot/boot.ipxe` directly.

**cuproxy** — CUPS print proxy that forwards print jobs from the contest network to the physical printer at `10.0.0.10:631`.

**Internet toggle** (run as root on geproxy):
```bash
enable-internet   # opens nftables chain — contest network can reach the internet
disable-internet  # flushes chain — contest network is isolated
```

**Traefik** reverse proxies HTTPS traffic (Cloudflare ACME DNS challenge) for:
- `judge.gehack.nl` → DOMjudge
- `loom.gehack.nl` → Loom contest platform
- `cds.gehack.nl` → Contest Data Server
- `imaged.gehack.nl` → imaged UI/API (port 8080)

Disk layout uses RAID1 mdadm with dual GRUB mirrors.

---

### `geminecraft` — LAN Party Server

A single-network host for LAN events: every ethernet NIC is enslaved to one bridge, wifi is the uplink.

**Network layout:**

| Bridge | Interface(s) | Subnet | Purpose |
|--------|-------------|--------|---------|
| `br-lan` | every ethernet NIC (systemd-networkd `Type=ether`) | 10.0.0.0/24 | LAN party network |

- `wl*` uses DHCP for upstream connectivity; the LAN has no internet until `enable-internet` is run
- dnsmasq provides DHCP, DNS and TFTP on `br-lan`, resolving `imaged.gehack.nl` and `minecraft.gehack.nl` to `10.0.0.1`
- BIOS and EFI clients chainload iPXE over TFTP, which then loads `menu.ipxe` from `modules/geminecraft/pxe.nix`

**Network boot menu** (10 s timeout, defaults to imaged):

| Entry | Target |
|-------|--------|
| `imaged` | `http://10.0.0.1:8080/boot/boot.ipxe` |
| `netbootxyz` | `netboot.xyz.efi` / `netboot.xyz.kpxe` over TFTP — its distro menus are fetched from `boot.netboot.xyz`, so this entry needs `enable-internet` |
| `local` | leaves iPXE and boots the local disk |

**imaged** runs as a native NixOS service bound to `10.0.0.1:8080`; the UI is served through Traefik on `https://imaged.gehack.nl:3000`.

**Minecraft** is a Velocity proxy (`itzg/mc-proxy:java25`) in front of four backends (`itzg/minecraft-server:java25`), all containers on the `minecraft` Docker network. Only the proxy is published on the bridge, on 25565/tcp; every player lands in `lobby` and picks a game from there:

| Server | Loader | World | Gamemode | Extra content | Slots | Heap |
|--------|--------|-------|----------|---------------|-------|------|
| `lobby` | Fabric | superflat, bedrock layer | adventure (forced), peaceful | `lobby-menu` datapack | 50 | 6% of RAM |
| `bedwars` | **Paper** | superflat `arena`, bedrock layer | survival, easy | `screamingbedwars` plugin | 8 | 18% of RAM |
| `survival` | Fabric | normal | survival, normal | — | 50 | 35% of RAM |
| `creative` | Fabric | normal | creative (forced), peaceful | `worldedit` | 50 | 12% of RAM |

Every server runs Minecraft 26.2 — `VERSION` is pinned so proxy and backends can never drift apart — in offline mode and without whitelist. The Fabric backends also get `fabric-api`, `lithium`, `ferrite-core`, `krypton`, `spark`; the Paper backend gets none of those (they are Fabric mods), which is why `worlds.<name>.type` selects the loader and only Fabric worlds receive the shared mod list. Mixing loaders behind one proxy is fine because `player-info-forwarding-mode = "none"` asks nothing of the backend beyond `online-mode=false`. `MEMORY` is a percentage, so heaps scale with the host's RAM (`-XX:MaxRAMPercentage`); the four backends total 71%, the proxy takes a flat 512M. World data lives in `/var/lib/minecraft/<server>`, proxy state in `/var/lib/minecraft/proxy`.

**Routing.** `try = [ "lobby" ]` sends every joining player to the lobby, and any backend kick fails them back there. Switching servers is Velocity's own `/server <name>`, which the proxy intercepts before it reaches a backend — bare `/server` also prints a clickable list. The lobby datapack (`modules/geminecraft/assets/lobby-menu`) greets each player once with a clickable menu whose entries run `/server bedwars|survival|creative`; `/trigger lobby_menu` reopens it. This is all vanilla text components, so unmodified clients work — no client mod, and no hub mod exists for 26.2.

**BedWars** is ScreamingBedWars (`screamingbedwars`, Paper). The plugin owns the whole round cycle — waiting lobby with countdown, start when an arena's minimum player count is reached, teams, shops, upgrades, spectators, and arena rebuilding after every match — so there is no queue datapack and no AI bots. Arenas are authored once in-game with `/bw admin <name> …` following <https://docs.screamingsandals.org/BedWars/latest/arena/>; build the map on the creative server and copy it in, or build it directly in the `arena` world. Minimum/maximum players and team size are per-arena settings, not server-wide ones.

That arena definition and `plugins/BedWars/config.yml` are **runtime state**, not declarative: the plugin rewrites its own config, so it lives in `/var/lib/minecraft/bedwars/plugins/BedWars/` and is not managed by Nix. Two knobs worth setting there by hand: `bungee.enabled: true` with `bungee.server: lobby` returns players to the lobby when a match ends, and `allow-spectator-join` decides whether latecomers can watch.

Consoles are per backend: `docker exec -it <server> rcon-cli` (`bedwars`, `survival`, `creative`, `lobby`). The `minecraft` container is the proxy and has no RCON.

Both flat worlds are a single bedrock layer under a void biome, so there is solid ground to stand on and nothing else in the way of an arena; a pure void (`"layers":[]`) would drop players into nothing. The lobby datapack is installed by a `minecraft-datapacks` oneshot unit that copies it into `<world>/datapacks` with writable modes before the container starts — `systemd.tmpfiles`' `C+` was tried first and only copies the top level of a read-only store path. Regenerate a world with `rm -rf /var/lib/minecraft/bedwars/arena`.

**Adding backends on other hosts.** A `[servers]` entry takes any `host:port`, so `arena2 = "10.0.0.5:25565"` is enough; add the name to the lobby menu function to make it clickable. With forwarding mode `none` the remote backend only needs `online-mode=false` plus a firewall limiting its port to the proxy — otherwise players can bypass the proxy and pick any username. Velocity runs `player-info-forwarding-mode = "none"` (`modules/geminecraft/assets/velocity.toml`), which is why the local backends publish no ports and the nftables forward chain only admits LAN traffic that a published port DNAT'ed (`ct status dnat`).

**Build fanout** is enabled here too, so `nixos-rebuild --target-host deploy@geminecraft` mirrors a closure to every LAN client (see `modules/fanout.nix`).

**Internet toggle** (run as root on geminecraft):
```bash
enable-internet   # opens nftables chain — LAN clients can reach the internet
disable-internet  # flushes chain — LAN is isolated
```

Disk layout uses RAID1 mdadm with dual GRUB mirrors.

---

### `scoreboard-laptop` — Scoreboard Kiosk

A minimal kiosk that boots directly into the ICPC presentation client, no desktop environment.

- Runs `cage` (Wayland compositor) as a single-app kiosk for the `kiosk` user
- Launches the ICPC presentation client (built from `modules/scoreboard-laptop/scoreboard.nix`) connecting to the Contest Data Server
- CDS credentials loaded from sops secrets at runtime
- Service restarts automatically on failure (5 s delay)
- Waits for `network-online.target` before starting

---

## Running It Yourself

### Prerequisites

- [Nix](https://nixos.org/download/) with flakes enabled
- SSH access to target hosts as `root`
- [sops](https://github.com/getsops/sops) and an age key for secrets — each target host needs its age key at `/etc/sops/hostkey`, and your personal key must be listed in `.sops.yaml`

Builds automatically use the [Cachix](https://app.cachix.org/) binary cache at `luukblankenstijn.cachix.org` (configured in `flake.nix` `nixConfig`).

### Fresh machine provisioning

Use `nixos-anywhere` for initial setup — it partitions disks (via disko) and installs NixOS in one step:

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#<TARGET> root@<IP>
```

### Deploying updates

From the `scripts/` directory:

```bash
# Remote deployment (fetches SSH keys from GitHub first)
./install.sh <FLAKE_TARGET> root@<IP>

# Local deployment (prompts for confirmation)
./install.sh <FLAKE_TARGET>
```

Or directly with nixos-rebuild:

```bash
nixos-rebuild switch --flake .#<FLAKE_TARGET> --target-host root@<IP> --build-host root@<IP>
```

ARM cross-build (requires a remote aarch64 builder):

```bash
nixos-rebuild switch --flake .#teammachine_arm \
  --target-host root@<IP> \
  --build-host root@<IP> \
  --option builders "ssh://root@<IP>"
```

### Testing with a VM

Build and run a QEMU VM for the contest workstation (SSH forwarded to host port 2222):

```bash
nix build .#packages.x86_64-linux.teammachine-vm
./result/bin/run-*-vm
ssh -p 2222 root@localhost
```

### Checking a configuration builds

```bash
nix build .#nixosConfigurations.teammachine.config.system.build.toplevel
nix build .#nixosConfigurations.geproxy.config.system.build.toplevel
nix build .#nixosConfigurations.geminecraft.config.system.build.toplevel
nix build .#nixosConfigurations.scoreboard-laptop.config.system.build.toplevel
```

### Formatting disks

For a fresh machine where you need to partition disks before installing (destructive — prompts for confirmation):

```bash
cd scripts
./format.sh <FLAKE_TARGET>
```

This runs disko in `destroy,format,mount` mode using the host's `disko.nix` layout.

### Updating flake inputs

```bash
nix flake update
```

---

## Contributing

### Repository structure

```
hosts/<host>/configuration.nix   # Host entry point — hardware config and module imports
hosts/<host>/disko.nix           # Disk partitioning layout
modules/<host>/                  # Host-specific modules
modules/                         # Shared modules (fanout, nix, sops, ssh, users)
users/<user>/                    # Home-manager configurations per user
scripts/                         # Deployment helper scripts
assets/                          # Shared assets (wallpaper, boot logo)
secrets.yaml                     # sops-encrypted secrets
```

### Adding a new module

1. Create `modules/<host>/mymodule.nix`.
2. Add it to `modules/<host>/default.nix` — without this import the module is never loaded.

### Adding a new host

1. Create `hosts/<host>/configuration.nix` and `hosts/<host>/disko.nix`.
2. Define a module list and `nixosSystem` call in `flake.nix`, following the pattern of existing hosts.
3. Wire in `mkHomeManager` if users need home-manager configs.

### Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age encryption. Key holders are listed in `.sops.yaml`; encrypted values live in `secrets.yaml`. Each deployed host reads its age key from `/etc/sops/hostkey`.

To add a secret:
1. Edit with `sops secrets.yaml` and add the key.
2. Reference it in a module via `config.sops.secrets.<name>.path`.

To add a new team member's key, add their age public key to `.sops.yaml` and re-encrypt with `sops updatekeys secrets.yaml`.

### SSH authorized keys

`authorized_keys` is generated by `scripts/update_keys.sh`, which fetches public keys from GitHub for each team member (currently: LuukBlankenstijn, BHenkemans, gewoonsandor, mexdeloo). The `install.sh` script calls this automatically. To add a new member, add their GitHub username to the `USERS` array in `update_keys.sh`.

### Firewall

The project uses nftables exclusively — do not introduce iptables rules. Geproxy rules live in `modules/geproxy/assets/firewall.nft`, geminecraft rules in `modules/geminecraft/assets/firewall.nft`. Teammachine rules are written inline in `modules/teammachine/networking.nix` using the `contest_subnet` and `judge_ip` specialArgs variables.

Hosts that run Docker must not `flush ruleset`: Docker keeps its own chains in the same ruleset and only rebuilds them when the daemon starts, so a flush breaks port publishing until the next `systemctl restart docker`. Geminecraft therefore sets `networking.nftables.flushRuleset = false` and lists its own tables in `extraDeletions`.
