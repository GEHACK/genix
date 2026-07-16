---
title: The GEHACK Live Image
description: The bootable GEHACK contest workstation — write it to a USB stick, boot, and you're in
---

The GEHACK workstation ships as a single bootable image, **`gehack-teammachine.iso`**. It is
the same **NixOS 26.05** system as a real team machine — same GNOME desktop, compilers,
editors and tooling — packaged as a live USB so you can boot it on almost any PC without
installing anything.

<p><a class="download-btn" href="https://gehack.gewis.nl/teammachine.iso">Download the ISO</a></p>

> Looking for what's *on* the machine? See the **[Contest Environment](index.md)**.

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

`sudo` runs without a password prompt — but only as the `gehack` user, which is the only
administrator. The auto-logged-in `team` user is a plain contest account: it **cannot**
`sudo`, and `su` to another user is blocked as well. Log in as `gehack` for anything that
needs root.

## The judge website

On the live image Firefox opens the public **DOMjudge demo** at
[www.domjudge.org/demoweb](https://www.domjudge.org/demoweb/) as its homepage (real team
machines point at the contest judge instead, which is only reachable on the contest
network). Log in to that demo instance with:

| Field | Value |
|----------|--------|
| Username | `team` |
| Password | `team` |

The `submit` command is pointed at the same demo instance, so you can try the full
submit-and-judge flow end to end.

## Good to know

- **Wifi and Bluetooth work** — connect from the GNOME top bar. (They are enabled on the
  live image even though real team machines have them locked down.)
- **Nothing persists.** The live session runs from RAM/USB; anything you create is gone
  after a reboot.
- **Hostname** is `gehack-iso`.
- **This is NixOS, not Debian/Ubuntu.** Software is managed declaratively and everything you
  need is already installed — package-manager commands like `apt`, `apt-get` and `dpkg` are
  not present and will not work.
