{
  config,
  lib,
  ...
}:
let
  kotlinPin = config.teammachine.languages.kotlin.pin;
in
{
  options.teammachine.languages.kotlin.pin = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          version = lib.mkOption {
            type = lib.types.str;
            example = "2.1.21";
            description = "Kotlin compiler release from github.com/JetBrains/kotlin.";
          };
          hash = lib.mkOption {
            type = lib.types.str;
            example = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            description = "SRI hash of kotlin-compiler-<version>.zip.";
          };
        };
      }
    );
    default = {
      version = "2.4.10";
      hash = "sha256-Rz3WbHo+9LGCBls9pnBGbBvydzqduw7Yszo5/p1Ph20=";
    };
    description = "Kotlin compiler release replacing the one in the toolchain nixpkgs; null keeps that version.";
  };

  config.nixpkgs.overlays = [
    (
      final: _prev:
      let
        inherit (final) toolchainPkgs;
        jdk = toolchainPkgs.jdk25;
      in
      {
        contestToolchain = {
          gcc = toolchainPkgs.gcc.overrideAttrs (old: {
            postFixup = old.postFixup + ''
              echo "-L${toolchainPkgs.glibc.static}/lib" >> $out/nix-support/cc-ldflags
            '';
          });
          inherit (toolchainPkgs) pypy3;
          inherit jdk;
          kotlin = (toolchainPkgs.kotlin.override { jre = jdk; }).overrideAttrs (
            lib.optionalAttrs (kotlinPin != null) {
              inherit (kotlinPin) version;
              src = toolchainPkgs.fetchurl {
                url = "https://github.com/JetBrains/kotlin/releases/download/v${kotlinPin.version}/kotlin-compiler-${kotlinPin.version}.zip";
                inherit (kotlinPin) hash;
              };
            }
          );
        };
      }
    )
  ];
}
