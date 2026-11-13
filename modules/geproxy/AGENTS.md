Applies to `modules/geproxy/` (geproxy host only) and `modules/geproxy/network/` (also imported alone by `tests/geproxy-network.nix`).

## Verify
- Evaluate `geproxy` with the root `## Verify` command; `network/` edits also need the `geproxy-network` check named there.
- Firewall edits: read the rendered rules with `nix eval --raw .#nixosConfigurations.geproxy.config.networking.nftables.tables.filter.content` (NAT is `tables.geproxy_nat.content`; `networking.nftables.ruleset` is empty here).
- dnsmasq config is checked only when the service starts (`ExecStartPre … --test` in `network/dnsmasq.nix`), never at eval or build.

## Rules
- A port a network may reach: register `geproxy.ports.<name>.{tcp,udp}` inside the module's `mkIf`, then add `<name>` to `geproxy.networks.<net>.allow` (or `uplink.allow`) in `hosts/geproxy/configuration.nix`. A name in `allow` with no `ports` entry (e.g. a disabled module) is an eval error.
- Do not register Caddy ports in `ports`: `network/firewall.nix` opens every port listed in a site's `expose.<net>` (plus 80 when 443 is listed).
- A web service: set `geproxy.proxy.sites.<name>.upstream` (and `login`/`extraConfig`) in the module; the host file sets `expose`/`tunnel`. `upstream` has no default, so disabling a module whose site the host still exposes fails eval.
- Keep `login = true` on `grafana`, `loom` and `imaged`: the host file tunnels all three to the internet, `monitoring.nix` runs Grafana with anonymous `Admin`, and `loom.nix` sets `trustedProxyHeader`.
- Upstreams may trust `X-Proxy-Authorized` only on `login` sites; `network/proxy.nix` strips the client's copy only when `login` is set.
- Site directives run in written order inside a Caddy `route`; anything in `extraConfig` that answers (`reverse_proxy`, `respond`) skips the login (intended for loom `/api/*` and gRPC in `loom.nix`).
- `default.nix` turns every non-empty, non-`#` line of `../../authorized_keys` into an operator key with forced command `fanout-dispatch`. That lets `deploy` (a Nix `trusted-users` entry) switch every fanout target as root; never loosen the forced command or its `no-*` flags in `fanout.nix`, and keep `services.buildFanout.sshKeyFile` a sops path, never a store path.
- Fanout ssh disables host-key checking and targets substitute from harmonia (`cache.nix`, port 5000) with `require-sigs false`; never expose `cache` beyond `contest`/`admin` or to `uplink`.
- `cuproxy.nix` hard-codes balloons' `127.0.0.1:8090`; change it together with `listenAddr` in `balloons.nix`.
- `tests/geproxy-network.nix` passes only `contest_id` and `imaged_port` as module args and only a `cloudflare-token` secret: a new specialArg or sops secret used in `network/` breaks `geproxy-network` until the test is updated.

## Traps
- DNS kill switch: output rules match `meta skuid "dnsmasq-<net>"` (users created in `network/dnsmasq.nix`); `preCheckRuleset` seds those to `nobody` because build-time `nft -c` has no such users. Renaming the user or the rule pattern silently breaks the switch or the check.
- `internet = "switchable"` creates empty chain `<net>_inet` in table `inet filter`; `network/tools.nix` hard-codes `inet filter` and `<net>_inet` in `enable-internet`/`disable-internet`. Rename the table or chain in both files.
- A deploy that changes the nftables unit recreates every declared table (`flushRuleset = false`), so each `<net>_inet` is empty again: internet is off until `enable-internet` is rerun. A deploy that leaves the unit unchanged keeps the toggle.
- Never name a network `uplink`: the name is the uplink's zone in `expose` and its dnsmasq instance under `uplink.announce`.
- Not covered by the test, so only the toplevel eval checks them: `allow`/`ports`, `pxe`, `wifi`, `tunnel`, `login`/`proxy.authentik`, `domain`, `dns.forward`, `dhcp.reservations`, `uplink.announce`, `insecureUpstream`.
