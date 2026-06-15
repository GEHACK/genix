# fanout.nix — turn this host into a build-fanout target.
#
# From your laptop:
#
#   # all online hosts from the inventory API:
#   nixos-rebuild switch --flake .#contestlaptop --target-host deploy@geproxy
#
#   # target a specific subset — set the list, then deploy as usual.
#   # The targets file is sticky: it overrides the inventory until cleared.
#   ssh deploy@geproxy targets 10.0.0.50 10.0.0.51
#   nixos-rebuild switch --flake .#contestlaptop --target-host deploy@geproxy
#
#   # clear and go back to inventory mode:
#   ssh deploy@geproxy targets
#
# What happens:
#   1. nixos-rebuild builds on your laptop and copies the closure to `fanout`.
#      A forced-command dispatcher hands the transfer to the fanout's real
#      nix-daemon, so the closure lands in its store (ONE transfer in).
#   2. nixos-rebuild's `nix-env --set` is captured (the system path is recorded;
#      the fanout's own system profile is left untouched).
#   3. nixos-rebuild's `switch-to-configuration <action>` is intercepted and,
#      instead of activating the fanout, mirrors the closure to every laptop your
#      inventory API reports as online — each receiving only its missing paths —
#      and runs `switch-to-configuration <action>` on each, in parallel.
#
# !!! VERIFY BEFORE TRUSTING !!!
#   The exact strings nixos-rebuild sends over SSH differ between the legacy
#   script and nixos-rebuild-ng, and between ssh:// and ssh-ng://. The dispatcher
#   below matches on substrings so it tolerates flag/wrapper drift (incl. ng's
#   systemd-run wrapper), but log $SSH_ORIGINAL_COMMAND from one real rebuild and
#   confirm the four cases below actually fire for YOUR version before relying on it.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.buildFanout;

  # ssh options used both for plain `ssh` and (via NIX_SSHOPTS) for `nix copy`.
  sshOpts = cfg.sshOpts ++ [ "-i" cfg.sshKeyFile ];

  # ---- the actual fanout: discover live hosts, copy deltas, activate ----
  fanout-deploy = pkgs.writeShellApplication {
    name = "fanout-deploy";
    runtimeInputs = with pkgs; [ nix openssh curl jq coreutils findutils ];
    text = ''
      systemPath="''${1:-}"
      action="''${2:-switch}"
      [ -n "$systemPath" ] || { echo "fanout-deploy: no system path" >&2; exit 1; }

      export NIX_SSHOPTS=${lib.escapeShellArg (lib.concatStringsSep " " sshOpts)}

      targetsFile="$HOME/.local/state/fanout/targets"

      # Host selection:
      #   - targets file present (set via `ssh deploy@... targets <ip>...`)
      #   - otherwise → query the inventory API
      hosts=()
      if [ -s "$targetsFile" ]; then
        mapfile -t hosts < "$targetsFile"
        echo "fanout-deploy: targets file → ''${#hosts[@]} host(s)" >&2
      else
        mapfile -t hosts < <(curl -fsS ${lib.escapeShellArg cfg.inventoryUrl} | jq -r '.[]')
        echo "fanout-deploy: inventory API → ''${#hosts[@]} host(s)" >&2
      fi
      [ "''${#hosts[@]}" -gt 0 ] || { echo "fanout-deploy: no hosts to deploy to" >&2; exit 1; }
      echo "fanout-deploy: mirroring $systemPath ($action) to ''${#hosts[@]} hosts" >&2

      failFile="$(mktemp)"
      trap 'rm -f "$failFile"' EXIT
      export failFile

      deploy_one() {
        host="$1"
        target="${cfg.targetUser}@$host"
        # `nix copy` negotiates per-host: only paths this host lacks are sent.
        if nix copy --to "ssh://$target" "$systemPath" \
             && ssh ${lib.escapeShellArgs sshOpts} "$target" \
                  "nix-env -p /nix/var/nix/profiles/system --set '$systemPath' \
                   && '$systemPath/bin/switch-to-configuration' '$action'"; then
          echo "ok   $host" >&2
        else
          echo "FAIL $host" >&2
          echo "$host" >> "$failFile"
          return 1
        fi
      }
      export -f deploy_one
      export systemPath action

      # Fan out in parallel; failures are recorded in $failFile (checked below).
      printf '%s\n' "''${hosts[@]}" \
        | xargs -r -P ${toString cfg.parallel} -I{} \
            bash -c 'deploy_one "$@"' _ {} || true

      if [ -s "$failFile" ]; then
        failed=$(wc -l < "$failFile")
        ok=$((''${#hosts[@]} - failed))
        echo "fanout-deploy: $ok ok, $failed failed (of ''${#hosts[@]}):" >&2
        while IFS= read -r h; do echo "  FAIL $h" >&2; done < "$failFile"
        exit 1
      fi
      echo "fanout-deploy: all ''${#hosts[@]} hosts done" >&2
    '';
  };

  # ---- forced-command dispatcher: classify $SSH_ORIGINAL_COMMAND ----
  fanout-dispatch = pkgs.writeShellApplication {
    name = "fanout-dispatch";
    runtimeInputs = with pkgs; [ nix coreutils gnugrep ];
    text = ''
      cmd="''${SSH_ORIGINAL_COMMAND:-}"
      stateDir="$HOME/.local/state/fanout"
      mkdir -p "$stateDir"
      log() { echo "fanout-dispatch: $*" >&2; }

      case "$cmd" in
        # --- target list: set/clear (sticky — survives across deploys) ---
        "targets")
          rm -f "$stateDir/targets"
          log "targets cleared (will use inventory API)" ;;
        "targets "*)
          raw="''${cmd#targets }"
          raw="''${raw//,/ }"
          hosts=()
          for h in $raw; do
            [ -n "$h" ] && hosts+=("$h")
          done
          if [ "''${#hosts[@]}" -eq 0 ]; then
            rm -f "$stateDir/targets"
            log "targets cleared (will use inventory API)"
          else
            printf '%s\n' "''${hosts[@]}" > "$stateDir/targets"
            log "targets set (''${#hosts[@]}): ''${hosts[*]}"
          fi ;;

        # --- closure transfer: hand straight to the real daemon ---
        *"nix-store --serve"*)
          exec nix-store --serve --write ;;
        *"nix daemon --stdio"*|*"nix-daemon --stdio"*)
          exec nix daemon --stdio ;;

        # --- nixos-rebuild-ng readiness probes (read-only, safe to run) ---
        *"test -d /run/systemd/system"*)
          exec test -d /run/systemd/system ;;
        *"test -f /nix/store/"*"/nixos-version"*)
          # closure-completeness probe — extract the path and let `test -f` run.
          path="$(printf '%s' "$cmd" | grep -oE '/nix/store/[^[:space:]"'"'"']+/nixos-version' | head -n1 || true)"
          [ -n "$path" ] || { log "no /nix/store nixos-version path in: $cmd"; exit 1; }
          exec test -f "$path" ;;

        # --- profile set: capture the path, leave system profile alone ---
        *"nix-env"*"--set"*)
          # `|| true` so a no-match grep doesn't trip `set -e` silently.
          path="$(printf '%s' "$cmd" | grep -oE '/nix/store/[^[:space:]"'"'"']+-nixos-system-[^[:space:]"'"'"'/]+' | head -n1 || true)"
          case "$path" in
            */nix/store/*nixos-system*) : ;;
            *) log "captured path doesn't look like a system closure: '$path' (cmd: $cmd)"; exit 1 ;;
          esac
          printf '%s' "$path" > "$stateDir/pending"
          # keep it rooted against GC in a side profile (NOT the system profile)
          nix-env -p "$stateDir/profile" --set "$path" >/dev/null
          log "captured $path" ;;

        # --- activation: the trigger to fan out ---
        *"switch-to-configuration"*)
          action="$(printf '%s' "$cmd" \
            | grep -oE 'switch-to-configuration[[:space:]]+[a-z-]+' \
            | awk '{print $2}' | head -n1 || true)"
          [ -n "$action" ] || action="switch"
          # Prefer the path captured by an earlier `nix-env --set`. If absent
          # (e.g. dry-activate, or nixos-rebuild-ng's "no systemd" fallback
          # path which skips the profile set), derive it from the activation
          # command itself: strip /bin/switch-to-configuration from the path.
          path="$(cat "$stateDir/pending" 2>/dev/null || true)"
          if [ -z "$path" ]; then
            path="$(printf '%s' "$cmd" \
              | grep -oE '/nix/store/[^[:space:]"'"'"']+/bin/switch-to-configuration' \
              | head -n1 || true)"
            path="''${path%/bin/switch-to-configuration}"
          fi
          case "$path" in
            */nix/store/*nixos-system*) : ;;
            *) log "no/invalid system path: '$path' (cmd: $cmd)"; exit 1 ;;
          esac
          log "fanning out $path ($action)"
          exec ${lib.getExe fanout-deploy} "$path" "$action" ;;

        *)
          log "refusing unrecognized command: $cmd"
          exit 1 ;;
      esac
    '';
  };
in
{
  options.services.buildFanout = {
    enable = lib.mkEnableOption "build-fanout host";

    inventoryUrl = lib.mkOption {
      type = lib.types.str;
      example = "http://localhost:8080/hosts-needing-rebuild";
      description = "URL returning a JSON array of online target host/IP strings.";
    };

    targetUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User to SSH into on the laptops (needs to run nix-env/switch).";
    };

    parallel = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Max concurrent host deployments.";
    };

    sshOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=accept-new" ];
      description = "Extra ssh options for reaching the laptops.";
    };

    sshKeyFile = lib.mkOption {
      type = lib.types.str; # a PATH ON THE HOST, not copied into the store
      example = "/run/secrets/fanout-ssh-key";
      description = ''
        Private key the fanout uses to reach the laptops. Must be a path on the
        deployed host (e.g. a sops-nix secret) — do NOT use a store path, or the
        key ends up world-readable in /nix/store.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Operator public keys allowed to drive the fanout.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.deploy = { };
    users.users.deploy = {
      isSystemUser = true;
      group = "deploy";
      home = "/var/lib/fanout";
      createHome = true;
      shell = pkgs.bashInteractive;
      # every operator key is pinned to the dispatcher; no shell, no forwarding.
      openssh.authorizedKeys.keys = map
        (k: ''command="${lib.getExe fanout-dispatch}",no-port-forwarding,no-x11-forwarding,no-agent-forwarding,no-pty ${k}'')
        cfg.authorizedKeys;
    };

    # deploy must be trusted so it can write to the store via the daemon
    # (nix-store --serve --write / nix daemon --stdio) without being root.
    nix.settings.trusted-users = [ "deploy" ];

    # expose the scripts for manual runs / debugging
    environment.systemPackages = [ fanout-deploy fanout-dispatch ];
  };
}
