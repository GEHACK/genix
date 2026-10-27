#!/usr/bin/env bash
set -euo pipefail

# Build the runtimes ISO with the problem set deploy key and the upload token
# decrypted from secrets.yaml. Both stay out of git (genix is public); the build is
# --impure to read them. Extra arguments go to `nix build`, e.g.
# --builders 'ssh://root@<IP> x86_64-linux'.
cd "$(dirname "$(readlink -f "$0")")/.."

secrets=$(mktemp -d)
trap 'rm -rf "$secrets"' EXIT
sops decrypt --extract '["runtimes-deploy-key"]' secrets.yaml >"$secrets/deploy_key"
sops decrypt --extract '["runtimes-upload-token"]' secrets.yaml >"$secrets/upload_token"

RUNTIMES_SECRETS="$secrets" nix build --impure .#runtimes-iso "$@"
echo "ISO: $(readlink -f result)/iso/gehack-runtimes.iso"
echo "Flash it with: sudo dd if=result/iso/gehack-runtimes.iso of=/dev/<usb-stick> bs=4M status=progress"
echo "Never push this ISO to a binary cache: it contains the deploy key and upload token."
