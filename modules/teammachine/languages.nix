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
    default = null;
    description = "Kotlin compiler release replacing the nixpkgs one; null keeps the nixpkgs version.";
  };

  config = lib.mkIf (kotlinPin != null) {
    nixpkgs.overlays = [
      (_final: prev: {
        kotlin = prev.kotlin.overrideAttrs {
          inherit (kotlinPin) version;
          src = prev.fetchurl {
            url = "https://github.com/JetBrains/kotlin/releases/download/v${kotlinPin.version}/kotlin-compiler-${kotlinPin.version}.zip";
            inherit (kotlinPin) hash;
          };
        };
      })
    ];
  };
}
