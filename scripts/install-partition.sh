#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <IMAGE> <PARTITION> <HOSTKEY>"
    echo ""
    echo "Arguments:"
    echo "  IMAGE      (Required) teammachine.img from 'nix build .#teammachine-part'"
    echo "  PARTITION  (Required) The existing partition to overwrite, e.g. /dev/nvme0n1p4"
    echo "  HOSTKEY    (Required) The sops age key, installed as /etc/sops/hostkey"
}

die() {
    echo "ERROR: $1" >&2
    usage >&2
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

[[ $# -eq 3 ]] || die "expected 3 arguments, got $#."

IMAGE="$1"
PARTITION="$2"
HOSTKEY="$3"

[[ $EUID -eq 0 ]] || die "must run as root."
[[ -f "$IMAGE" ]] || die "image '$IMAGE' does not exist."
[[ -f "$HOSTKEY" ]] || die "hostkey '$HOSTKEY' does not exist."
[[ -b "$PARTITION" ]] || die "'$PARTITION' is not a block device."
[[ "$(lsblk -no TYPE "$PARTITION")" == "part" ]] || die "'$PARTITION' is not a partition."
! findmnt --source "$PARTITION" >/dev/null || die "'$PARTITION' is mounted."

IMAGE_SIZE=$(stat -c %s "$IMAGE")
PARTITION_SIZE=$(blockdev --getsize64 "$PARTITION")
((IMAGE_SIZE <= PARTITION_SIZE)) || die "image needs $IMAGE_SIZE bytes, '$PARTITION' has $PARTITION_SIZE."

for LABELLED in $(blkid -o device -t LABEL=teammachine || true); do
    [[ "$(realpath "$LABELLED")" == "$(realpath "$PARTITION")" ]] ||
        die "$LABELLED is already labelled 'teammachine'; remove or relabel it first."
done

echo "DANGER: This will overwrite ALL data on $PARTITION:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$PARTITION"
read -rp "This is a DESTRUCTIVE operation. Are you sure? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

dd if="$IMAGE" of="$PARTITION" bs=4M conv=fsync status=progress
e2fsck -fp "$PARTITION"
resize2fs "$PARTITION"

MOUNTPOINT=$(mktemp -d)
trap 'umount "$MOUNTPOINT" 2>/dev/null || true; rmdir "$MOUNTPOINT"' EXIT

mount "$PARTITION" "$MOUNTPOINT"
install -D -m 0400 "$HOSTKEY" "$MOUNTPOINT/etc/sops/hostkey"

PROFILES="$MOUNTPOINT/nix/var/nix/profiles"
SYSTEM="$MOUNTPOINT$(readlink "$PROFILES/$(readlink "$PROFILES/system")")"
KERNEL_PARAMS=$(cat "$SYSTEM/kernel-params")
umount "$MOUNTPOINT"

echo "Installed. Host GRUB entry:"
echo "menuentry \"Teammachine\" {"
echo "    search --no-floppy --label teammachine --set=root"
echo "    linux /nix/var/nix/profiles/system/kernel init=/nix/var/nix/profiles/system/init $KERNEL_PARAMS"
echo "    initrd /nix/var/nix/profiles/system/initrd"
echo "}"
