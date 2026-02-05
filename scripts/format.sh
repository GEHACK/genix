#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 <FLAKE_TARGET>"
    echo ""
    echo "Arguments:"
    echo "  FLAKE_TARGET   (Required) The nixosConfiguration name to pull disko config from"
    exit 0
fi

FLAKE_TARGET="${1:-}"

if [[ -z "$FLAKE_TARGET" ]]; then
    echo "ERROR: FLAKE_TARGET is required."
    echo "Usage: $0 <FLAKE_TARGET>"
    exit 1
fi

echo "DANGER: This will partition and FORMAT disks on the CURRENT host using flake #$FLAKE_TARGET."
read -p "This is a DESTRUCTIVE operation. Are you sure? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

echo "Running Disko locally..."

sudo nix run github:nix-community/disko -- \
    --mode destroy,format,mount \
    --flake ".#$FLAKE_TARGET"
