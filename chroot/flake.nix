{
  description = "DOMjudge chroot";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.default = pkgs.buildEnv {
        name = "container-packages";
        paths = with pkgs; [
          glibc.static
          gcc
          gdb
          cmake
          pypy3
          python3
          jdk21
          kotlin
        ];
      };
    };
}