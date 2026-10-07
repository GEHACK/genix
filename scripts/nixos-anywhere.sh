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
    echo "  -B, --build-host <ssh-host>       Build on this host and run the installer from it."
    echo "                                    The flake is sent with 'nix flake archive', build"
    echo "                                    results stay rooted in ~/.local/state/genix-provision."
    echo "                                    The ssh user must be a trusted nix user there."
    echo "                                    Ssh options then describe build host -> target,"
    echo "                                    and the ssh agent is forwarded to the build host."
    echo "      --cache <url>                 Binary cache on the build host that the installer"
    echo "                                    downloads the closure from, e.g. http://10.0.1.1:5000."
    echo "                                    Requires --build-host."
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
SSH_OPTIONS=()
CACHE=""

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
        --cache)
            require_value "$@"
            CACHE="$2"
            shift 2
            ;;
        -J | --jump)
            require_value "$@"
            SSH_OPTIONS+=("ProxyJump=$2")
            shift 2
            ;;
        -o | --ssh-option)
            require_value "$@"
            SSH_OPTIONS+=("$2")
            shift 2
            ;;
        -p | --ssh-port)
            require_value "$@"
            SSH_OPTIONS+=("Port=$2")
            shift 2
            ;;
        -A | --forward-agent)
            SSH_OPTIONS+=(ForwardAgent=yes)
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

[[ -z "$CACHE" || -n "$BUILD_HOST" ]] || die "--cache requires --build-host."

SSH_ARGS=()
for option in "${SSH_OPTIONS[@]}"; do
    EXTRA_ARGS+=(--ssh-option "$option")
    SSH_ARGS+=(-o "$option")
done

"$SCRIPT_DIR/update_keys.sh"

echo "DANGER: This will partition $TARGET_HOST and install NixOS configuration #$FLAKE_TARGET."
read -p "Are you sure you want to wipe the remote disk and install? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

[[ -n "$CACHE" ]] || EXTRA_ARGS+=(--no-substitute-on-destination)

if [[ -z "$BUILD_HOST" ]]; then
    [[ -z "$EXTRA_FILES" ]] || EXTRA_ARGS+=(--extra-files "$EXTRA_FILES")
    for i in "${!DISK_KEY_LOCAL[@]}"; do
        EXTRA_ARGS+=(--disk-encryption-keys "${DISK_KEY_REMOTE[$i]}" "${DISK_KEY_LOCAL[$i]}")
    done

    echo "Starting deployment to $TARGET_HOST..."
    nix run "$REPO_ROOT#nixos-anywhere" -- \
        --flake "$REPO_ROOT#$FLAKE_TARGET" \
        "${EXTRA_ARGS[@]}" \
        "$TARGET_HOST"
    exit 0
fi

echo "Copying the flake and its inputs to $BUILD_HOST..."
FLAKE_SRC="$(nix flake archive --json --to "ssh-ng://$BUILD_HOST" "$REPO_ROOT" | jq -r .path)"

GC_ROOTS=".local/state/genix-provision"
ssh "$BUILD_HOST" "mkdir -p $GC_ROOTS"

build_on_host() {
    ssh "$BUILD_HOST" "$(printf '%q ' nix build --print-out-paths \
        --out-link "$GC_ROOTS/$1" "$FLAKE_SRC#$2")"
}

echo "Building $FLAKE_TARGET on $BUILD_HOST..."
SYSTEM_ATTR="nixosConfigurations.$FLAKE_TARGET.config.system.build"
DISKO_SCRIPT="$(build_on_host "$FLAKE_TARGET-diskoScript" "$SYSTEM_ATTR.diskoScript")"
TOPLEVEL="$(build_on_host "$FLAKE_TARGET-toplevel" "$SYSTEM_ATTR.toplevel")"
NIXOS_ANYWHERE="$(build_on_host nixos-anywhere packages.x86_64-linux.nixos-anywhere)"

if [[ -n "$EXTRA_FILES" || ${#DISK_KEY_LOCAL[@]} -gt 0 ]]; then
    REMOTE_ROOT="$(ssh "$BUILD_HOST" 'mktemp -d')"
    trap 'ssh "$BUILD_HOST" "rm -rf -- $REMOTE_ROOT"' EXIT
fi

if [[ -n "$EXTRA_FILES" ]]; then
    tar -C "$EXTRA_FILES" -czf - . |
        ssh "$BUILD_HOST" "mkdir -p $REMOTE_ROOT/extra-files && tar -xzf - -C $REMOTE_ROOT/extra-files"
    EXTRA_ARGS+=(--extra-files "$REMOTE_ROOT/extra-files")
fi

for i in "${!DISK_KEY_LOCAL[@]}"; do
    ssh "$BUILD_HOST" "mkdir -p $REMOTE_ROOT/disk-keys && cat > $REMOTE_ROOT/disk-keys/$i" <"${DISK_KEY_LOCAL[$i]}"
    EXTRA_ARGS+=(--disk-encryption-keys "${DISK_KEY_REMOTE[$i]}" "$REMOTE_ROOT/disk-keys/$i")
done

run_installer() {
    ssh -A -t "$BUILD_HOST" "$(printf '%q ' "$NIXOS_ANYWHERE/bin/nixos-anywhere" \
        --store-paths "$DISKO_SCRIPT" "$TOPLEVEL" "${EXTRA_ARGS[@]}" "$@" "$TARGET_HOST")"
}

echo "Starting deployment to $TARGET_HOST from $BUILD_HOST..."
if [[ -z "$CACHE" ]]; then
    run_installer
    exit 0
fi

run_installer --phases kexec

echo "Pointing the installer at $CACHE..."
printf '%s\n' "substituters = $CACHE" "require-sigs = false" "connect-timeout = 5" |
    ssh -A "$BUILD_HOST" "$(printf '%q ' ssh "${SSH_ARGS[@]}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${TARGET_HOST#*@}" \
        'mkdir -p ~/.config/nix && cat > ~/.config/nix/nix.conf')"

run_installer --phases disko,install,reboot
