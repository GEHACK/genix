#!/usr/bin/env bash
set -euo pipefail

USERS=("LuukBlankenstijn" "BHenkemans" "gewoonsandor")
OUTPUT_FILE="authorized_keys"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 <FLAKE_TARGET> [root@IP_OR_HOSTNAME]"
    echo ""
    echo "Arguments:"
    echo "  FLAKE_TARGET   (Required) The nixosConfiguration name"
    echo "  TARGET_HOST    (Optional) The ssh destination. If omitted, applies locally."
    exit 0
fi

FLAKE_TARGET="${1:-}"
TARGET_HOST="${2:-}"

if [[ -z "$FLAKE_TARGET" ]]; then
    echo "ERROR: FLAKE_TARGET is required."
    echo "Usage: $0 <FLAKE_TARGET> [root@IP_OR_HOSTNAME]"
    exit 1
fi

# Safety check for local deployment
if [[ -z "$TARGET_HOST" ]]; then
    echo "WARNING: No target host provided. This will apply '$FLAKE_TARGET' to the CURRENT host."
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi

./update_keys.sh

if [[ -n "$TARGET_HOST" ]]; then
    echo "Deploying to $TARGET_HOST using flake #$FLAKE_TARGET..."
    nixos-rebuild switch \
      --flake "../#$FLAKE_TARGET" \
      --target-host "$TARGET_HOST" 
else
    echo "Deploying locally using flake #$FLAKE_TARGET..."
    sudo nixos-rebuild switch --flake "../#$FLAKE_TARGET"
fi
