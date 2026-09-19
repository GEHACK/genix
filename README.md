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
- Firewall drops all traffic to `contest_subnet` except to/from `geproxy_ip`; `geproxy_ip:8443` (`cds_port`) is dropped as well, so teammachines cannot reach the CDS
- Sleep, hibernate, and suspend are all disabled
- Trackpad toggle (`teammachine.trackpad.enable`, `users/common/trackpad.nix`): `<Super>T` or the laptop's touchpad-toggle key flips `org.gnome.desktop.peripherals.touchpad send-events`, and a "Toggle Trackpad" launcher entry does the same for mouse users

---

### `geproxy` — Router / Firewall

Acts as the contest network router. Runs on hardware with multiple NICs bridged into two networks.

**Network layout:**

| Bridge | Interface(s) | Subnet | Purpose |
|--------|-------------|--------|---------|
| `br-admin` | `eno2` | 10.0.1.0/24 | Admin / organiser network |
| `br-contest` | `eno3–eno6` | 10.0.0.0/24 | Contest / team network |

- `wlp6s0` and `eno1` use DHCP for upstream connectivity
- Two dnsmasq instances, one per bridge: `dnsmasq` serves the contest bridge as uid 995, `dnsmasq-admin` serves the admin bridge as uid 994. Only the contest one is caught by the internet kill switch, so admin DNS keeps working while the contest network is isolated
- Both instances resolve `judge.gehack.nl`, `loom.gehack.nl`, `cds.gehack.nl`, `imaged.gehack.nl`, and `docs.gehack.nl` to geproxy — `10.0.0.1` on the contest bridge, `10.0.1.1` on the admin bridge — and forward everything else to the upstream servers geproxy itself learned over DHCP
- systemd-resolved runs with `MulticastDNS=resolve` so geproxy can resolve `.local` names announced on either bridge; it does not announce anything itself
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
- `cds.gehack.nl` → Contest Data Server, discovered over mDNS at `cds.local:8443` (`geproxy.cds.url`); its TLS certificate is not verified, so a self-signed CDS cert works. Two routers serve it: `cds-admin` on the normal `websecure` entryPoint (443), restricted to `admin_subnet` by a `ClientIP` matcher, and `cds-contest` on its own `cds-contest` entryPoint at `cds_port` (8443) for everything else. Contest-network clients therefore get 404 on 443, and teammachines drop 8443 outbound, so only organiser machines and the scoreboard kiosk reach the CDS
- `imaged.gehack.nl` → imaged UI/API (port 8080)

Disk layout uses RAID1 mdadm with dual GRUB mirrors.

The NIC layout, the RAID1 boot and the admin network are options (`geproxy.network.uplink`, `geproxy.network.contestInterfaces`, `geproxy.network.admin.enable`, `geproxy.network.admin.interfaces`, `geproxy.raidBoot.enable`), defaulted to this machine.

---

### `geproxy-laptop` — Router / Firewall on a teammachine laptop

The same role as `geproxy` on teammachine hardware: one NVMe disk, one ethernet port, wifi uplink. Identical services (dnsmasq, Traefik, imaged, cuproxy, balloons, devdocs, fanout, NTP) and the same contest bridge and firewall, minus everything admin-network:

- `geproxy.network.admin.enable = false` — no `br-admin`, no `dnsmasq-admin`, no `admin-net-secure` Traefik entryPoint and no `cds-admin` router. Organiser traffic uses the contest bridge
- `enp0s31f6` is the sole member of `br-contest`; `wlp0s20f3` is the uplink — check both against `ip -br link` on the actual laptop and adjust `hosts/geproxy-laptop/configuration.nix` if the kernel names them differently
- `geproxy.raidBoot.enable = false` — single-disk GPT/ext4 on `/dev/nvme0n1`, plain EFI GRUB
- `networking.hostName` is still `geproxy`; do not run both machines on one LAN

---

### `scoreboard-laptop` — Scoreboard Kiosk

A minimal kiosk that boots directly into the ICPC presentation client, no desktop environment.

- Runs `cage` (Wayland compositor) as a single-app kiosk for the `kiosk` user
- Launches the ICPC presentation client (built from `modules/scoreboard-laptop/scoreboard.nix`) connecting to the Contest Data Server at `https://cds.gehack.nl:8443` (`scoreboard.cdsUrl`, defaulted from the `cds_port` specialArg)
- CDS credentials loaded from sops secrets at runtime
- Service restarts automatically on failure (5 s delay)
- Waits for `network-online.target` before starting

---

### `balloons-laptop` — Balloon Runner Kiosk

A minimal kiosk that boots straight into a chromeless Chromium on the balloons dashboard, no desktop environment.

- Runs `cage` as a single-app kiosk for the `kiosk` user; no login prompt, no window chrome
- Opens `https://balloons.gehack.nl` (`balloons.url`), served by the `balloons` service on geproxy
- Chromium runs `--app=`, not `--kiosk`: under ozone-wayland `--kiosk` still renders the tab strip and omnibox
- Profile lives in the unit's `PrivateTmp`, so every start is a clean session with no crash-restore prompts
- `networking.dhcpcd.wait = "ipv4"` holds `network-online.target` until the lease lands, so Chromium never opens before DNS works; the service restarts automatically (5 s delay)
- Plug it into the admin network: `balloons.gehack.nl` resolves there through the admin resolver. The contest bridge only answers for the names in `proxiedHosts` (`modules/geproxy/networking.nix`), which does not include balloons

---

### `cds` — Contest Data Server

Runs the ICPC CDS container (`ghcr.io/icpctools/cds`) on the admin network, feeding the scoreboard kiosk.

- CDS listens on 8443 with a self-signed certificate; contest data lives in `/var/lib/cds`
- All CDS passwords come from sops; `CCS_URL` points at `judge.gehack.nl`, which the admin resolver sends to geproxy so the `__CONTEST__` placeholder gets rewritten
- avahi announces `cds.local`, which is how geproxy's Traefik finds it — no DHCP reservation needed
- Root accepts `fanout_pubkey`, so geproxy can deploy to it like a teammachine

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
nix build .#nixosConfigurations.geproxy-laptop.config.system.build.toplevel
nix build .#nixosConfigurations.scoreboard-laptop.config.system.build.toplevel
nix build .#nixosConfigurations.balloons-laptop.config.system.build.toplevel
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

The project uses nftables exclusively — do not introduce iptables rules. Both rulesets are written inline in Nix — `modules/geproxy/networking.nix` and `modules/teammachine/networking.nix` — and are built from the `geproxy_ip`, `contest_subnet`, `admin_ip`, `admin_subnet` and `imaged_port` specialArgs.
