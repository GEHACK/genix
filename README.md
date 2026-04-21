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
- `pxe-reboot` command — sets EFI next-boot to the PXE/IPv4 entry and reboots (for FOG reimaging)
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
- Contest DNS resolves `judge.gehack.nl`, `loom.gehack.nl`, `cds.gehack.nl`, `fog.gehack.nl` to `10.0.0.1`
- PXE/FOG boot configured for BIOS and EFI clients via dnsmasq `dhcp-boot`

**FOG imaging server** runs as a Docker container (`fog-server` + `fog-db` MariaDB) for disk imaging and deployment of teammachines over the contest network. Accessible at `fog.gehack.nl` via Traefik.

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
- `fog.gehack.nl` → FOG imaging server (port 3000 / 443)

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
modules/                         # Shared modules (nix, sops, ssh, users)
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

`authorized_keys` is generated by `scripts/update_keys.sh`, which fetches public keys from GitHub for each team member (currently: LuukBlankenstijn, BHenkemans, gewoonsandor, zeo). The `install.sh` script calls this automatically. To add a new member, add their GitHub username to the `USERS` array in `update_keys.sh`.

### Firewall

The project uses nftables exclusively — do not introduce iptables rules. Geproxy rules live in `modules/geproxy/assets/firewall.nft`. Teammachine rules are written inline in `modules/teammachine/networking.nix` using the `contest_subnet` and `judge_ip` specialArgs variables.
