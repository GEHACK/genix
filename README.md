# GEHACK NixOS Infrastructure

NixOS flake-based infrastructure-as-code for the GEHACK competitive programming competitions like FPC, EAPC and EUC26. This repository manages fully declarative system configurations for contest workstations, a network router/firewall, and a scoreboard kiosk — all defined in Nix with no imperative package management.

---

## Machines

### `teammachine` — Contest Workstation

The primary machine used by contestants during a competition.

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
- [`submit`](https://github.com/DOMjudge/DOMjudge) CLI from the [`domjudge-submit`](https://github.com/GEHACK/domjudge-submit-nix) flake input, pre-configured to submit to DOMjudge (URL set via `dj_url` specialArgs in `flake.nix`)
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

Acts as the contest network router. Runs on hardware with multiple NICs bridged into two networks. The whole network is declared in one `geproxy` block in `hosts/geproxy/configuration.nix`; `modules/geproxy/network/` generates the bridges, dnsmasq instances, nftables ruleset and Caddy config from it.

| Network | Bridge | Interface(s) | Subnet | Internet | Reaches |
|---------|--------|--------------|--------|----------|---------|
| `admin` | `br-admin` | `eno1`, `eno2` | 10.0.1.0/24 | always | `contest` |
| `contest` | `br-contest` | `eno3–eno6` | 10.0.0.0/24 | switchable | — |

- `wlp6s0` (`geproxy.uplink.interface`) is the uplink: DHCP, the only interface NAT masquerades to
- Each network (`geproxy.networks.<name>`) gets its own bridge and a `dnsmasq-<name>` unit running as user `dnsmasq-<name>`. DHCP leases are infinite and stored in `/var/lib/dnsmasq-<name>/`
- A network only answers DNS on its own geproxy address, so contest clients cannot use the admin resolver
- `internet = "switchable"` routes both forwarding and that network's upstream DNS through chain `<name>_inet`. `enable-internet [network]` / `disable-internet [network]` toggle it, defaulting to `geproxy.internetToggle.default` (the first switchable network). Any `nixos-rebuild switch` reloads the ruleset and disables it again
- `allow` lists the entries of `geproxy.ports` reachable on geproxy (`ssh`, `ntp`, `printing`, `imaged`); service modules register their ports there
- `pxe.enable` adds TFTP and the BIOS/EFI `dhcp-boot` chain into imaged
- systemd-resolved runs with `MulticastDNS=resolve` so geproxy can resolve `.local` names announced on either bridge
- `wol` wakes every machine in every network's lease file

Every service is behind a `geproxy.<service>.enable` toggle in the host file: `ntp`, `ddns`, `loomDns`, `cuproxy`, `imaged`, `balloons`, `devdocs`, `cds`.

**imaged** runs as native NixOS services (`imaged-server` + `imaged-tftp`) for disk imaging and deployment of teammachines over the contest network. PXE clients use `http://10.0.0.1:8080/boot/boot.ipxe` directly.

**cuproxy** — CUPS print proxy that forwards print jobs from the contest network to the physical printer at `10.0.0.10:631`.

**Caddy** reverse proxies HTTPS for the sites in `geproxy.proxy.sites`. One Let's Encrypt certificate covers all of them, issued by `security.acme` through the Cloudflare DNS challenge. `expose` says, per network (or `uplink`), on which ports a site is served:
- The network's resolver points the site's hostname at geproxy, and the firewall opens those ports on it
- A client from a network the site is not exposed to gets 404, even on a port another site opened
- Port 80 redirects to HTTPS wherever 443 is exposed

| Site | Upstream | admin | contest | uplink |
|------|----------|-------|---------|--------|
| `judge.gehack.nl` | DOMjudge, `__CONTEST__` rewritten to `contest_id` | 443 | 443 | 443 |
| `loom.gehack.nl` | Loom | 443 | 443 | 443 |
| `docs.gehack.nl` | DevDocs container | 443 | 443 | 443 |
| `balloons.gehack.nl` | balloons dispatcher | 443 | — | — |
| `cds.gehack.nl` | CDS at `cds.local:8443` over mDNS (`geproxy.cds.url`), certificate not verified | 443, 8443 | 8443 | — |
| `imaged.gehack.nl` | imaged UI | 3000 | — | 3000 |

Teammachines drop 8443 outbound, so on the contest network only the scoreboard kiosk reaches the CDS.

Disk layout uses RAID1 mdadm with dual GRUB mirrors (`geproxy.raidBoot.enable`).

`nix build .#checks.x86_64-linux.geproxy-network` boots geproxy with a contest client, an admin client and an upstream host, and checks DHCP, DNS, per-network site access, reachability and the internet switch.

---

### `scoreboard` — Scoreboard Kiosk

A minimal kiosk that boots directly into the ICPC presentation client, no desktop environment.

- Runs `cage` (Wayland compositor) as a single-app kiosk for the `kiosk` user
- Launches the ICPC presentation client (from the [`icpc-presentation`](https://github.com/GEHACK/icpc-presentation-nix) flake input) connecting to the Contest Data Server at `https://cds.gehack.nl:8443` (`scoreboard.cdsUrl`, defaulted from the `cds_port` specialArg)
- CDS credentials loaded from sops secrets at runtime
- Service restarts automatically on failure (5 s delay)
- Waits for `network-online.target` before starting

---

### `balloons` — Balloon Runner Kiosk

A minimal kiosk that boots straight into a chromeless Chromium on the balloons dashboard, no desktop environment.

- Runs `cage` as a single-app kiosk for the `kiosk` user; no login prompt, no window chrome
- Opens `https://balloons.gehack.nl` (`balloons.url`), served by the `balloons` service on geproxy
- Chromium runs `--app=`, not `--kiosk`: under ozone-wayland `--kiosk` still renders the tab strip and omnibox
- Profile lives in the unit's `PrivateTmp`, so every start is a clean session with no crash-restore prompts
- `networking.dhcpcd.wait = "ipv4"` holds `network-online.target` until the lease lands, so Chromium never opens before DNS works; the service restarts automatically (5 s delay)
- Plug it into the admin network: `balloons.gehack.nl` is only exposed there

---

### `cds` — Contest Data Server

Runs the ICPC CDS container (`ghcr.io/icpctools/cds`) on the admin network, feeding the scoreboard kiosk.

- CDS listens on 8443 with a self-signed certificate; contest data lives in `/var/lib/cds`
- All CDS passwords come from sops; `CCS_URL` points at `judge.gehack.nl`, which the admin resolver sends to geproxy so the `__CONTEST__` placeholder gets rewritten
- avahi announces `cds.local`, which is how geproxy's Caddy finds it — no DHCP reservation needed
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
nix build .#nixosConfigurations.scoreboard.config.system.build.toplevel
nix build .#nixosConfigurations.balloons.config.system.build.toplevel
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

The project uses nftables exclusively — do not introduce iptables rules. geproxy's ruleset is generated by `modules/geproxy/network/firewall.nix` from the `geproxy` options; the teammachine ruleset is written inline in `modules/teammachine/networking.nix` from the `geproxy_ip`, `contest_subnet` and `cds_port` specialArgs.
