#!/usr/bin/env bash
set -euo pipefail

USERS=("LuukBlankenstijn" "BHenkemans" "gewoonsandor" "mexdeloo" "kevinjil" "tuupke" "nickygerritsen" "aarhunt")
JUDGEHOST_USERS=("eldering")
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

write_keys() {
    local output_file="$1"
    shift
    local temp_file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' RETURN

    for user in "$@"; do
        echo "Fetching keys for $user..."
        local keys
        keys=$(curl -sf "https://github.com/${user}.keys" || true)

        if [[ -z "$keys" || ! "$keys" == *"ssh-"* ]]; then
            echo "ERROR: No public keys found for user: $user" >&2
            exit 1
        fi

        {
            echo "# $user"
            echo "$keys"
            echo ""
        } >> "$temp_file"
    done

    mv "$temp_file" "$output_file"

    if [ -e "$REPO_ROOT/.git" ]; then
        git -C "$REPO_ROOT" add "$output_file"
        echo "Staged $output_file in Git."
    fi
}

write_keys "$REPO_ROOT/authorized_keys" "${USERS[@]}"
write_keys "$REPO_ROOT/judgehost_authorized_keys" "${JUDGEHOST_USERS[@]}"
