{ pkgs, lib, ... } :
let
  blockedCommands = [
    "nix" "nix-build" "nix-channel" "nix-collect-garbage" "nix-copy-closure"
    "nix-daemon" "nix-env" "nix-hash" "nix-info" "nix-instantiate"
    "nix-prefetch-url" "nix-shell" "nix-store" "nixos-build-vms"
    "nixos-enter" "nixos-generate-config" "nixos-help" "nixos-install"
    "nixos-option" "nixos-rebuild" "nixos-version"
  ];

  blockScript = pkgs.writeShellScript "nix-disabled" ''
    echo "Nix commands are disabled for this account." >&2
    exit 1
  '';

  blockNixPkg = pkgs.runCommand "block-nix-commands" {} ''
    mkdir -p $out/bin
    ${lib.concatMapStrings (cmd: "ln -s ${blockScript} $out/bin/${cmd}\n") blockedCommands}
  '';
in 
{
  home.packages = with pkgs; [ blockNixPkg ];
}