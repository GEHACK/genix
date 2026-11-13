Applies to `modules/teammachine/`: the contestant laptop role. Single files are also imported by path into the ISO, judgehost, utility and the RDP test.

## Verify
- Evaluate `teammachine` with the root `## Verify` command, plus every other importer of the file you edited:
  - `desktop`, `geproxy`, `languages`, `locale`, `networking`, `printer`, `netboot`, `usbguard` or `user-tools.nix`: `teammachine-iso`.
  - `geproxy.nix` or `netboot.nix`: `judgehost` and `utility`. `languages.nix`: `judgehost` (its judge chroot is built from `contestToolchain`).
- Ruleset edits: read the rendered result with `nix eval --raw .#nixosConfigurations.teammachine.config.networking.nftables.ruleset`.

## Rules
- `networking.nix` holds the only firewall (inline nftables, `policy drop` on input, forward and output). A service that calls geproxy needs its port in `toGeproxy.tcp`/`.udp`, or its traffic is dropped.
- An inbound TCP service needs its port in `fromTrusted` (accepted only from geproxy and `admin_subnet`). Inbound UDP has no list, so write a rule like the loom video one.
- In the ruleset, use the `geproxy` let-binding, never a literal `@geproxy`: `set geproxy` exists only when `teammachine.geproxy.discover` is on.
- Services reach geproxy via `config.teammachine.geproxy.host` (mDNS name or IP), never `geproxy_ip` directly; with discover on, `geproxy_ip` is wrong and the `judge` extraHosts entry is gone.
- Build `contestToolchain` from `final`, never `prev`: `prev.gcc` is a different gcc from the `pkgs.gcc` the machines run, and `prev.kotlin` misses the kotlin pin overlay, which is merged after it.
- Every attr of `contestToolchain` lands in the judge chroot (`modules/judgehost/chroot.nix` takes `lib.attrValues`, passed in by `flake.nix`). Adding or renaming an attr changes what the judge runs.
- Keep the lockdown: `iwlwifi`/`btusb` blacklist and NetworkManager polkit deny (`networking.nix`), disabled sleep/suspend/hibernate targets (`desktop.nix`), `teammachine.usbguard.enable` (`usbguard.nix`, on in `hosts/teammachine/configuration.nix`).

## Traps
- `default.nix` reaches only the teammachine host. A new file there never reaches the ISO; add it to `hosts/teammachine-iso/configuration.nix` too if the ISO needs it.
- The by-path files (the nine above, and `remote-desktop.nix` for `tests/teammachine-rdp.nix`) must not be renamed or start depending on a non-imported sibling (`boot`, `greeter`, `station`, `users`, `remote-desktop`). `netboot.nix` and `printer.nix` already need `geproxy.nix`.
- `networking.nix` reads `teammachine.remoteDesktop` and `services.greetd.loom-greeter` with `or { enable = false; }`, and the streams port with `lib.attrByPath` (see `users/AGENTS.md`), because the ISO imports none of their modules; keep those guards.
- `networking.firewall.allowedUDPPorts` in `geproxy.nix` does nothing here (firewall disabled; mDNS is accepted by `networking.nix`) but is live on judgehost and utility, which import the file and run the stock firewall. Do not delete it as dead code.
