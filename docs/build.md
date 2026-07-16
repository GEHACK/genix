---
title: The GEHACK Live Image
description: The bootable GEHACK contest workstation — write it to a USB stick, boot, and you're in
---

The GEHACK workstation ships as a single bootable image, **`gehack-teammachine.iso`**. It is
the same **NixOS 26.05** system as a real team machine — same GNOME desktop, compilers,
editors and tooling — packaged as a live USB so you can boot it on almost any PC without
installing anything.

> Looking for what's *on* the machine? See the **[Contest Environment](index.md)**.

## How it's built

The whole system — desktop, compilers, editors, firewall, users — is declared as code in a
[NixOS](https://nixos.org/) flake and evaluated into one reproducible image. The same
configuration always produces the same machine, with no imperative package installs. You
don't build it yourself: the ready-made `gehack-teammachine.iso` is produced from the flake
and handed to you.

## Writing the ISO to a USB stick

The image is hybrid (BIOS **and** UEFI bootable) and is written **as a whole disk** (not a
partition).

> ⚠️ **Writing to the wrong disk erases it.** Double-check the device name before running
> any command — there is no undo. All data on the target USB stick is destroyed.

### GUI (any OS, easiest)

[balenaEtcher](https://etcher.balena.io/) works on Linux, macOS and Windows: select
`gehack-teammachine.iso`, select the USB stick, click **Flash**. On Windows, [Rufus](https://rufus.ie/)
is a good alternative (use *DD Image* mode when prompted).

### Linux

```bash
lsblk                            # identify the USB, e.g. /dev/sdb (NOT /dev/sdb1)
sudo dd if=gehack-teammachine.iso of=/dev/sdb bs=4M status=progress oflag=sync
sync
```

### macOS

```bash
diskutil list                    # identify the USB, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=gehack-teammachine.iso of=/dev/rdisk4 bs=4m   # note: rdisk4 is faster than disk4
diskutil eject /dev/disk4
```

## Booting and logging in

Boot the target machine from the USB stick (usually F12 / F11 / Esc at power-on to open the
boot menu, or enable USB boot in the BIOS/UEFI settings). The image boots on both BIOS and
UEFI systems.

There is **no login screen**: GDM auto-logs the `team` user straight into GNOME. You land on
the desktop ready to work.

Two accounts exist, both with the password **`password`**:

| User | Role | Password |
|--------|-------------------------------|------------|
| `team` | contest user (auto-logged in) | `password` |
| `gehack` | administrator (`sudo`/`wheel`) | `password` |

`sudo` does not prompt for a password on the live image, so you can run admin commands
without typing it.

## Good to know

- **Wifi and Bluetooth work** — connect from the GNOME top bar. (They are enabled on the
  live image even though real team machines have them locked down.)
- **Nothing persists.** The live session runs from RAM/USB; anything you create is gone
  after a reboot.
- **Hostname** is `gehack-iso`.
