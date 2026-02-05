#!/usr/bin/env bash
set -euo pipefail

USERS=("LuukBlankenstijn" "BHenkemans" "gewoonsandor")
OUTPUT_FILE="authorized_keys"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 <FLAKE_TARGET> <root@IP_OR_HOSTNAME>"
    echo ""
    echo "Arguments:"
    echo "  FLAKE_TARGET   (Required) The nixosConfiguration name"
    echo "  TARGET_HOST    (Required) The ssh destination (e.g., root@1.1.1.1)"
    exit 0
fi

FLAKE_TARGET="${1:-}"
TARGET_HOST="${2:-}"

if [[ -z "$FLAKE_TARGET" || -z "$TARGET_HOST" ]]; then
    echo "ERROR: Missing arguments."
    echo "Usage: $0 <FLAKE_TARGET> <root@IP_OR_HOSTNAME>"
    exit 1
fi

./update_keys.sh

# 2. Safety Warning
echo "DANGER: This will partition $TARGET_HOST and install NixOS configuration #$FLAKE_TARGET."
read -p "Are you sure you want to wipe the remote disk and install? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# 3. Run nixos-anywhere
# This handles Disko automatically if it's part of your flake configuration
echo "Starting deployment to $TARGET_HOST..."
nix run github:nix-community/nixos-anywhere -- \
    --flake "../#$FLAKE_TARGET" \
    "$TARGET_HOST"
