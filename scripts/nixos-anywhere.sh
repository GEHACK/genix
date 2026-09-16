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
    echo "  -B, --build-host <ssh-host>       Run the installer from this host, so the closure"
    echo "                                    is built there and copied to the target directly."
    echo "                                    Ssh options then describe build host -> target,"
    echo "                                    and the ssh agent is forwarded to the build host."
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
BUILD_HOST=""
IDENTITY=""
EXTRA_FILES=""
DISK_KEY_REMOTE=()
DISK_KEY_LOCAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -B | --build-host)
            require_value "$@"
            BUILD_HOST="$2"
            shift 2
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
            IDENTITY="$2"
            shift 2
            ;;
        --extra-files)
            require_value "$@"
            [[ -d "$2" ]] || die "--extra-files needs a directory, got '$2'."
            EXTRA_FILES="$2"
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
            DISK_KEY_REMOTE+=("$2")
            DISK_KEY_LOCAL+=("$3")
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

if [[ -n "$IDENTITY" ]]; then
    [[ -z "$BUILD_HOST" ]] || die "--identity cannot be combined with --build-host, forward your ssh agent instead."
    EXTRA_ARGS+=(-i "$IDENTITY")
fi

"$SCRIPT_DIR/update_keys.sh"

echo "DANGER: This will partition $TARGET_HOST and install NixOS configuration #$FLAKE_TARGET."
read -p "Are you sure you want to wipe the remote disk and install? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

if [[ -z "$BUILD_HOST" ]]; then
    [[ -z "$EXTRA_FILES" ]] || EXTRA_ARGS+=(--extra-files "$EXTRA_FILES")
    for i in "${!DISK_KEY_LOCAL[@]}"; do
        EXTRA_ARGS+=(--disk-encryption-keys "${DISK_KEY_REMOTE[$i]}" "${DISK_KEY_LOCAL[$i]}")
    done

    echo "Starting deployment to $TARGET_HOST..."
    nix run github:nix-community/nixos-anywhere -- \
        --flake "$REPO_ROOT#$FLAKE_TARGET" \
        "${EXTRA_ARGS[@]}" \
        "$TARGET_HOST"
    exit 0
fi

REMOTE_ROOT="$(ssh "$BUILD_HOST" 'mktemp -d')"
trap 'ssh "$BUILD_HOST" "rm -rf -- $REMOTE_ROOT"' EXIT

echo "Copying the working tree to $BUILD_HOST:$REMOTE_ROOT/flake..."
tar -C "$REPO_ROOT" --exclude=./.git --exclude=./tmp -czf - . |
    ssh "$BUILD_HOST" "mkdir -p $REMOTE_ROOT/flake && tar -xzf - -C $REMOTE_ROOT/flake"

if [[ -n "$EXTRA_FILES" ]]; then
    tar -C "$EXTRA_FILES" -czf - . |
        ssh "$BUILD_HOST" "mkdir -p $REMOTE_ROOT/extra-files && tar -xzf - -C $REMOTE_ROOT/extra-files"
    EXTRA_ARGS+=(--extra-files "$REMOTE_ROOT/extra-files")
fi

for i in "${!DISK_KEY_LOCAL[@]}"; do
    ssh "$BUILD_HOST" "mkdir -p $REMOTE_ROOT/disk-keys && cat > $REMOTE_ROOT/disk-keys/$i" <"${DISK_KEY_LOCAL[$i]}"
    EXTRA_ARGS+=(--disk-encryption-keys "${DISK_KEY_REMOTE[$i]}" "$REMOTE_ROOT/disk-keys/$i")
done

echo "Starting deployment to $TARGET_HOST, building on $BUILD_HOST..."
ssh -A -t "$BUILD_HOST" "$(printf '%q ' nix run github:nix-community/nixos-anywhere -- \
    --flake "$REMOTE_ROOT/flake#$FLAKE_TARGET" "${EXTRA_ARGS[@]}" "$TARGET_HOST")"
