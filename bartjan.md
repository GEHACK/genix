# Commands for Bartjan

## nixos-anywhere

`nix run github:nix-community/nixos-anywhere -- --flake .#teammachine root@<TARGET_IP_ADDRESS>`

## nixos-build

1. `nix-shell -p nixos-rebuild`
2. `nixos-rebuild switch  --flake .#teammachine_arm   --target-host root@192.168.64.11   --build-host root@192.168.64.11   --option builders "ssh://root@192.168.64.11"`
