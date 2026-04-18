#!/usr/bin/env bash
set -euo pipefail

USERS=("LuukBlankenstijn" "BHenkemans" "gewoonsandor" "zeo")
OUTPUT_FILE="../authorized_keys"

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

for USER in "${USERS[@]}"; do
    echo "Fetching keys for $USER..."
    KEYS=$(curl -sf "https://github.com/${USER}.keys")

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

if [ -d .git ]; then
    git add "$OUTPUT_FILE"
    echo "Staged $OUTPUT_FILE in Git."
fi
