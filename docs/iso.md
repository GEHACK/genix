# teammachine-iso — Live Test ISO

A bootable ISO image of the `teammachine` contest workstation, intended for people who want to try out the GEHACK environment without provisioning a real machine.

It is the **same** system as `teammachine` — same desktop, same toolchains, same IDEs, same login flow via `loom-greeter` — with a few targeted changes so it can run as a live USB on arbitrary hardware.

---

## Differences vs. `teammachine`

| | `teammachine` | `teammachine-iso` |
|---|---|---|
| Disk | partitioned by `disko.nix` | live image, no install |
| Bootloader | custom GRUB with EUC2027 splash (`modules/teammachine/boot.nix`) | provided by `iso-image.nix` |
| GPU | Nvidia Optimus (PRIME offload) | generic — `hardware.graphics` only |
| Secrets file | `secrets.yaml` (host-key provisioned out of band) | `secrets-iso.yaml` (age key baked into the image) |
| Hostname | `team` | `gehack-iso` |
| Wifi / Bluetooth | kernel modules blacklisted (`iwlwifi`, `btusb`) | enabled |

Everything else — `loom-greeter` autologin to `team`, `loomd`, contest nftables firewall, USBGuard, GNOME, all languages and IDEs, `submit`, webcamstream — is identical.

---

## Building

The ISO is `packages.x86_64-linux.teammachine-iso` in the flake.

On a Linux host:

```bash
nix build .#packages.x86_64-linux.teammachine-iso
# result/iso/gehack-teammachine.iso
```

On macOS (the nix-daemon can't read your `~/.ssh/config`, so pass the IP and key path explicitly):

```bash
nix build .#packages.x86_64-linux.teammachine-iso \
  --builders "ssh-ng://root@<linux-builder-ip> x86_64-linux /Users/<you>/.ssh/id_ed25519 4" \
  --max-jobs 0 \
  --option builders-use-substitutes true
```

---

## Flashing

```bash
# Linux
sudo dd if=result/iso/gehack-teammachine.iso of=/dev/sdX bs=4M status=progress conv=fsync

# macOS — find the disk with `diskutil list`, then:
diskutil unmountDisk /dev/diskN
sudo dd if=result/iso/gehack-teammachine.iso of=/dev/rdiskN bs=4m
```

Or use [balenaEtcher](https://etcher.balena.io/) / Rufus.

The ISO is hybrid (`makeEfiBootable` + `makeUsbBootable`), so it boots on both BIOS and UEFI systems.

---

## Secrets

The ISO uses its own secrets file `secrets-iso.yaml`, encrypted to the public key listed as `iso-key` in `.sops.yaml`. The matching private key lives in the repository at `./iso-key` and is baked into the image at `/etc/sops/hostkey` so `sops-nix` can decrypt at boot.

This means **the iso-key is public** — anyone with the ISO can extract it from the Nix store and decrypt `secrets-iso.yaml`. That is intentional: the secrets in there are throwaway demo credentials. Never reuse this key for anything that needs to stay secret.

To add or change a value:

```bash
SOPS_AGE_KEY_FILE=./iso-key sops secrets-iso.yaml
```

After editing `.sops.yaml` (e.g. adding a new key holder), re-encrypt with:

```bash
sops updatekeys secrets-iso.yaml
```

---

## Known limitations

- No persistence — anything done in the live session is gone after reboot.
- The contest nftables firewall is still active and drops the `contest_subnet` (10.0.0.0/24) except to/from `judge_ip` (10.0.0.1). On a normal network this is harmless; on a contest network it behaves like a real teammachine.
- `loom-greeter` tries to reach `judge.gehack.nl` to authenticate. Without internet the login will fail — use a network that can resolve and reach the public DOMjudge instance.
- No Nvidia drivers, so hybrid-graphics laptops fall back to Intel/AMD integrated graphics. PRIME offload (`prime-run`) won't work.
- The image is large (multi-GB) because it includes all IDEs and toolchains.
