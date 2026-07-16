---
title: Image Build Instructions
description: How the GEHACK team machines are built — declaratively, with NixOS
---

The GEHACK machines are **not imaged by hand**. Every workstation is defined as code in a
[NixOS](https://nixos.org/) flake — the same configuration produces the same machine every
time, with no imperative package installs. This page describes how that image is built and
deployed.

> Looking for what's *on* the machine? See the **[Contest Environment](index.md)**.

## How it works

The whole system — desktop, compilers, editors, firewall, users — is declared in Nix and
evaluated into a single system closure. Rebuilding after a config change is atomic and
reversible; there is no drift between machines.

| Target | Architecture | Purpose |
|--------|--------------|---------|
| `teammachine` | x86_64 | Contest workstation |

## Writing the ISO to a USB stick

The workstation image is also available as a bootable ISO. Below, `teammachine.iso`
is the image file and the USB stick is written **as a whole disk** (not a partition).

> ⚠️ **Writing to the wrong disk erases it.** Double-check the device name before
> running any command — there is no undo. All data on the target USB stick is destroyed.

### GUI (any OS, easiest)

[balenaEtcher](https://etcher.balena.io/) works on Linux, macOS and Windows: select
`teammachine.iso`, select the USB stick, click **Flash**. On Windows, [Rufus](https://rufus.ie/)
is a good alternative (use *DD Image* mode when prompted).

### Linux

```bash
lsblk                            # identify the USB, e.g. /dev/sdb (NOT /dev/sdb1)
sudo dd if=teammachine.iso of=/dev/sdb bs=4M status=progress oflag=sync
sync
```

### macOS

```bash
diskutil list                    # identify the USB, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=teammachine.iso of=/dev/rdisk4 bs=4m   # note: rdisk4 is faster than disk4
diskutil eject /dev/disk4
```

Then boot the target machine from the USB stick (usually F12 / F11 / Esc at power-on to
open the boot menu, or enable USB boot in the BIOS/UEFI settings).

## Prerequisites

- [Nix](https://nixos.org/download/) with flakes enabled
- SSH access to the target host as `root`
- [sops](https://github.com/getsops/sops) with an age key for secrets — your public key
  must be listed in `.sops.yaml`

Builds automatically use the [Cachix](https://app.cachix.org/) binary cache at
`luukblankenstijn.cachix.org`, so most of the closure is fetched rather than compiled.

## Fresh machine provisioning

[`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere) does initial setup in
one step — it partitions the disks (via disko) and installs NixOS:

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#<TARGET> root@<IP>
```

## Deploying updates

From the `scripts/` directory:

```bash
# Remote deployment (fetches SSH keys from GitHub first)
./install.sh <TARGET> root@<IP>

# Local deployment (prompts for confirmation)
./install.sh <TARGET>
```

Or directly with nixos-rebuild:

```bash
nixos-rebuild switch --flake .#<TARGET> --target-host root@<IP> --build-host root@<IP>
```

## Testing in a VM

Build and run a QEMU VM for the contest workstation (SSH forwarded to host port 2222):

```bash
nix build .#packages.x86_64-linux.teammachine-vm
./result/bin/run-*-vm
ssh -p 2222 root@localhost
```

## Checking a configuration builds

```bash
nix build .#nixosConfigurations.teammachine.config.system.build.toplevel
```

## Formatting disks

For a fresh machine that needs partitioning before install (destructive — prompts for
confirmation):

```bash
cd scripts
./format.sh <TARGET>
```

This runs disko in `destroy,format,mount` mode using the host's `disko.nix` layout.

## Updating dependencies

```bash
nix flake update
```
