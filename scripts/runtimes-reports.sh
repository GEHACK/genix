#!/usr/bin/env bash
set -euo pipefail

# Fetch the encrypted runtimes reports from the receiver container and print each
# summary. The receiver only holds age ciphertext; decryption happens here, with your
# own key.
#
# Usage: [DOCKER_HOST=ssh://user@server] scripts/runtimes-reports.sh [container]
#   container defaults to runtimes-receiver
# The age identity defaults to your sops age key; set RUNTIMES_AGE_IDENTITY to use
# another, such as ~/.ssh/id_ed25519.
cd "$(dirname "$(readlink -f "$0")")/.."

if ! command -v age >/dev/null; then
  exec nix shell --inputs-from . nixpkgs#age nixpkgs#python3 --command "$0" "$@"
fi

container=${1:-runtimes-receiver}

identity=${RUNTIMES_AGE_IDENTITY:-${SOPS_AGE_KEY_FILE:-}}
if [[ -z "$identity" ]]; then
  for candidate in "$HOME/Library/Application Support/sops/age/keys.txt" "$HOME/.config/sops/age/keys.txt"; do
    [[ -r "$candidate" ]] && identity=$candidate && break
  done
fi
[[ -n "$identity" ]] || { echo "No age identity found; set RUNTIMES_AGE_IDENTITY." >&2; exit 1; }

# tmp/ is gitignored, so decrypted reports never get committed.
dir=tmp/runtimes-reports
mkdir -p "$dir"
chmod 0700 "$dir"
# No -t: a tty would mangle the binary tar stream.
docker exec "$container" python3 /app/receiver.py export /data | tar -x -C "$dir"

shopt -s nullglob
for encrypted in "$dir"/*.age; do
  report=${encrypted%.age}.json
  [[ -e "$report" ]] || age --decrypt --identity "$identity" --output "$report" "$encrypted"
  printf '\n\033[1m%s\033[0m\n' "$(basename "$report" .json)"
  python3 modules/runtimes-iso/assets/report.py summary "$report"
done
echo
echo "Full reports, including the bt logs: $dir/*.json"
