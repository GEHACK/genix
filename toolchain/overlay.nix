# Contest-wide compiler pins. Applied to every host via modules/toolchain.nix, so the
# teammachines and the judgehost chroot resolve to the same store paths.
_final: prev: {
  kotlin = prev.kotlin.overrideAttrs {
    version = "2.4.20";
    src = prev.fetchurl {
      url = "https://github.com/JetBrains/kotlin/releases/download/v2.4.20/kotlin-compiler-2.4.20.zip";
      hash = "sha256-WenKdMeQTvLBIrEhFJN2c8zOaN6CCmY/DtZsz4eZ4Lc=";
    };
  };
}
