#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: $0 [options] <FLAKE_TARGET> <root@IP_OR_HOSTNAME>"
    echo ""
    echo "Arguments:"
    echo "  FLAKE_TARGET   (Required) The nixosConfiguration name"
    echo "  TARGET_HOST    (Required) The ssh destination (e.g., root@1.1.1.1)"
    echo ""
    echo "Options:"
    echo "  -J, --jump <ssh-host>              Proxy jump through this host, can be repeated"
    echo "  -o, --ssh-option <k=v>            Extra ssh option without '-o', can be repeated"
    echo "  -p, --ssh-port <port>             Ssh port of the target host"
    echo "  -A, --forward-agent               Forward the local ssh agent to the target"
    echo "  -i, --identity <file>             Ssh private key used to reach the target"
    echo "      --extra-files <dir>           Copy the contents of <dir> onto / of the new system"
    echo "      --chown <path> <user:group>   Ownership for an extra file, path relative to /"
    echo "      --disk-encryption-keys <remote-path> <local-file>"
    echo "                                    Upload a key file into the installer before partitioning"
    echo "      --debug                       Enable nixos-anywhere debug output"
}

die() {
    echo "ERROR: $1" >&2
    usage >&2
    exit 1
}

require_value() {
    [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value."
}

require_two_values() {
    [[ $# -ge 3 && -n "$2" && -n "$3" ]] || die "$1 requires two values."
}

EXTRA_ARGS=()
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -J | --jump)
            require_value "$@"
            EXTRA_ARGS+=(--ssh-option "ProxyJump=$2")
            shift 2
            ;;
        -o | --ssh-option)
            require_value "$@"
            EXTRA_ARGS+=(--ssh-option "$2")
            shift 2
            ;;
        -p | --ssh-port)
            require_value "$@"
            EXTRA_ARGS+=(--ssh-port "$2")
            shift 2
            ;;
        -A | --forward-agent)
            EXTRA_ARGS+=(--ssh-option ForwardAgent=yes)
            shift
            ;;
        -i | --identity)
            require_value "$@"
            EXTRA_ARGS+=(-i "$2")
            shift 2
            ;;
        --extra-files)
            require_value "$@"
            [[ -d "$2" ]] || die "--extra-files needs a directory, got '$2'."
            EXTRA_ARGS+=(--extra-files "$2")
            shift 2
            ;;
        --chown)
            require_two_values "$@"
            EXTRA_ARGS+=(--chown "$2" "$3")
            shift 3
            ;;
        --disk-encryption-keys)
            require_two_values "$@"
            [[ -f "$3" ]] || die "--disk-encryption-keys needs a local file, got '$3'."
            EXTRA_ARGS+=(--disk-encryption-keys "$2" "$3")
            shift 3
            ;;
        --debug)
            EXTRA_ARGS+=(--debug)
            shift
            ;;
        -*)
            die "Unknown option '$1'."
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

[[ ${#POSITIONAL[@]} -eq 2 ]] || die "Expected exactly 2 arguments, got ${#POSITIONAL[@]}."

FLAKE_TARGET="${POSITIONAL[0]}"
TARGET_HOST="${POSITIONAL[1]}"

[[ "$TARGET_HOST" == *@* ]] || die "TARGET_HOST '$TARGET_HOST' must be <user>@<host>."

"$SCRIPT_DIR/update_keys.sh"

echo "DANGER: This will partition $TARGET_HOST and install NixOS configuration #$FLAKE_TARGET."
read -p "Are you sure you want to wipe the remote disk and install? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

echo "Starting deployment to $TARGET_HOST..."
nix run github:nix-community/nixos-anywhere -- \
    --flake "$REPO_ROOT#$FLAKE_TARGET" \
    "${EXTRA_ARGS[@]}" \
    "$TARGET_HOST"
