Applies to `docs/`: the public contestant site (`docs/CNAME`), a Jekyll site on the `github-pages` gem with the cayman theme. Nothing in the flake or any workflow in this repo builds it.

## Verify
- No check in this repo covers `docs/`. Local preview per `docs/Gemfile`, from `docs/`: `bundle install`, then `bundle exec jekyll serve`.

## Rules
- Published to everyone: never add internal IPs, operator names, ssh/deploy details, key holders or secrets.
- Every contestant-facing claim mirrors Nix; change both in the same commit, and check the Nix side before editing text:
  - `mygcc`/`mygpp` flags in `docs/index.md` ↔ `users/team/languages.nix`.
  - VS Code `-std=c++23` / `-std=c17` ↔ `users/team/vscode.nix`; JDK 21 ↔ `jdk = final.jdk21` in `modules/teammachine/languages.nix`.
  - "Good to know": Nix commands blocked ↔ `users/team/nix-block.nix`; WiFi/Bluetooth off ↔ `boot.blacklistedKernelModules` in `modules/teammachine/networking.nix`; USB ↔ `modules/teammachine/usbguard.nix`; locked homepage ↔ `users/common/firefox.nix`.
  - `docs/build.md` ISO facts (filename, hostname `gehack-iso`, GDM autologin, wifi/bluetooth on, sudo rules) ↔ `hosts/teammachine-iso/configuration.nix`; DOMjudge demo URL ↔ `isoSpecialArgs.dj_url` in `flake.nix`.
- `docs/build.md` calls the ISO "the same" system as a real team machine; it is a fork (GDM instead of the greeter, no printer, trackpad toggle, usbguard, streams or remote desktop). Check `hosts/teammachine-iso/configuration.nix` before describing a teammachine feature there.

## Traps
- Keep the empty `---`/`---` front matter at the top of `docs/assets/css/style.scss`; without it Jekyll does not process the Sass and the theme overrides vanish.
