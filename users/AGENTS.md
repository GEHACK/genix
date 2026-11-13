Applies to `users/`: home-manager modules wired by `mkHomeManager` in `flake.nix`. `team` loads on teammachine and teammachine-iso; `gehack` and `users/common` (shared module) also load on geproxy and utility; judgehost and cds load none.

## Verify
- Evaluate with the root `## Verify` command: `teammachine` and `teammachine-iso` for `users/team/`; those two plus `geproxy` and `utility` for `users/common/` or `users/gehack/`.
- After changing a `users` mapping in `flake.nix`: `nix eval --json .#nixosConfigurations.<host>.config.home-manager.users --apply builtins.attrNames` must still list the users above.

## Rules
- Register a new file in the `imports` of `users/common/default.nix`, `users/team/default.nix` or `users/gehack/default.nix`, or it never loads.
- Declare HM toggles as `options.teammachine.<feature>` and gate with `lib.mkIf`. Hosts set them via `teammachine.users.<user>` (`hosts/teammachine/configuration.nix`, `hosts/teammachine-iso/configuration.nix`); geproxy and utility set `home-manager.users.gehack.teammachine.*` directly (`hosts/geproxy/configuration.nix`, `modules/utility/users.nix`). Rename an option at every one of these sites.
- `pkgs` here is the system `pkgs` (`useGlobalPkgs = true` in `flake.nix`): put overlays and `nixpkgs.config` in a system module, not in `users/`.
- `users/team/languages.nix` wrapper flags (`mygcc`, `mygpp`, `mypython`, `myjavac`, `mykotlinc`) and the VS Code build tasks in `users/team/vscode.nix` are published to contestants: update `docs/index.md` (and the `README.md` toolchain list) in the same change.
- Do not weaken `users/team/nix-block.nix` (unconditional for `team`) or the Firefox `policies` in `users/common/firefox.nix` (extension block, locked homepage) without explicit approval: they are contest lockdown.
- The only specialArg used here is `dj_url`; the ISO overrides it via `isoSpecialArgs` → `extraSpecialArgs`, so never hardcode the judge URL.

## Traps
- `modules/teammachine/networking.nix` reads `home-manager.users.team.teammachine.streams.{enable,port}` (declared in `users/team/streams.nix`) via `lib.attrByPath … null`; renaming the option silently closes the streams port with no eval error.
- `chroot/Containerfile` copies `users/team/languages.nix` by path; renaming it breaks the CI image build on the next push to `main`.
