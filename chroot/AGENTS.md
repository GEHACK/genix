Applies to `chroot/`: the `genix-chroot` Docker image that `.github/workflows/chroot.yml` builds and pushes to `ghcr.io/<owner>/<repo>/genix-chroot:latest` on every push to `main` and on manual dispatch. Nothing in the root flake, `hosts/` or `modules/` consumes it.

## Verify
- CI is the only build. Its local equivalent per the workflow, from the repo root: `docker build -f chroot/Containerfile .`.

## Rules
- This is NOT the judge's chroot. The judgehost mounts the Nix-built `modules/judgehost/chroot.nix` (from `pkgs.contestToolchain`, wired in `modules/judgehost/judgedaemon.nix`). Put judging changes there; editing `chroot/flake.nix` changes nothing a contest judge runs.
- `chroot/flake.nix` is a standalone flake on its own unlocked `nixos-unstable`: its compiler versions are unrelated to the team machines' and to the root `flake.lock`. Do not add it to the root flake or import root modules from it.

## Traps
- The build context is the repo root (`context: .`), so every `COPY` source is repo-root relative. The Containerfile copies `./chroot/flake.nix` and `./users/team/languages.nix`: renaming either breaks the image build.
- No `chroot/flake.lock` is committed and the Containerfile would not copy one. Evaluating `./chroot` locally writes one unless you pass `--no-write-lock-file`; do not commit it.
- Every push to `main` overwrites the single `:latest` tag; there is no SHA tag to roll back to.
