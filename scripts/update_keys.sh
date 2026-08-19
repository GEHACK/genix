#!/usr/bin/env bash
set -euo pipefail

USERS=("LuukBlankenstijn" "BHenkemans" "gewoonsandor" "mexdeloo")
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/authorized_keys"

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

for USER in "${USERS[@]}"; do
    echo "Fetching keys for $USER..."
    KEYS=$(curl -sf "https://github.com/${USER}.keys" || true)

    if [[ -z "$KEYS" || ! "$KEYS" == *"ssh-"* ]]; then
        echo "ERROR: No public keys found for user: $USER" >&2
        exit 1
    fi

    {
        echo "# $USER"
        echo "$KEYS"
        echo ""
    } >> "$TEMP_FILE"
done

mv "$TEMP_FILE" "$OUTPUT_FILE"

if [ -d "$REPO_ROOT/.git" ]; then
    git -C "$REPO_ROOT" add "$OUTPUT_FILE"
    echo "Staged $OUTPUT_FILE in Git."
fi
