Applies to `tests/`: the NixOS VM tests behind `checks.x86_64-linux` in `flake.nix`.

## Verify
- `nix build .#checks.x86_64-linux.geproxy-network` and `nix build .#checks.x86_64-linux.teammachine-rdp`, on an x86_64-linux builder only: elsewhere they fail at eval, because sops-nix reads the test's generated `secrets.yaml` (import-from-derivation of `<test>-test-secrets`). A host toplevel `nix eval` does not exercise these files.

## Rules
- Tests are not auto-discovered: a new `tests/<name>.nix` takes `{ pkgs, lib, sopsModule }` and needs its own entry under `checks.x86_64-linux` in `flake.nix`, passing `sops-nix.nixosModules.sops` as `sopsModule`.
- Never point a test at the repo `secrets.yaml` or `/etc/sops/hostkey`. Each test builds a throwaway age key and encrypts an inline fixture in a `runCommand`; the key lands in the store on purpose, so never reuse it.
- Keep the asserted fixtures: `contestId = "test"` in `geproxy-network.nix` (checked as `/api/test/x`, not the flake's `contest_id`), and `password = "hunter2"` in `teammachine-rdp.nix` (asserted via `grdctl` and `xfreerdp`). They are not real secrets.

## Traps
- Nodes get no flake `specialArgs` and no `hosts/*` config. The `geproxy` node imports only `modules/geproxy/network` and sets `_module.args` to `contest_id` and `imaged_port`; a module there that takes another specialArg (e.g. `geproxy_ip`) needs it added to that `_module.args`.
- Fixture secrets hold only the keys the imported modules declare: `cloudflare-token` (`modules/geproxy/network/proxy.nix`) and `password` (`modules/teammachine/remote-desktop.nix`). A new `sops.secrets.<name>` in those modules needs the key added to the test's `plain.yaml`.
- `teammachine-rdp` imports only `modules/teammachine/remote-desktop.nix`, defines the `team` user itself, and replaces the greeter with an inline Python `stubGreeter`; the script hardcodes uid 1000 (`/run/user/1000`).
- A green check covers only `modules/geproxy/network/` under the test's own networks and sites, and `remote-desktop.nix`; it says nothing about `hosts/geproxy/configuration.nix` or the rest of either role. The uncovered network options are listed in `modules/geproxy/AGENTS.md`.
