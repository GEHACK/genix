{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.teammachine.ides;
  langs = config.teammachine.languages;

  idea = pkgs.jetbrains.idea;
  kotlin = pkgs.kotlin;

  wizardStdlibVersion = "2.4.0";

  stdlibPom = pkgs.writeText "kotlin-stdlib-${wizardStdlibVersion}.pom" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <project xmlns="http://maven.apache.org/POM/4.0.0">
      <modelVersion>4.0.0</modelVersion>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-stdlib</artifactId>
      <version>${wizardStdlibVersion}</version>
      <packaging>jar</packaging>
    </project>
  '';

  seedStdlib = pkgs.writeShellScript "idea-kotlin-stdlib" ''
    set -euo pipefail

    bundled="${idea}/idea/plugins/Kotlin/kotlinc/lib"
    stdlibJar="$bundled/kotlin-stdlib.jar"
    stdlibSources="$bundled/kotlin-stdlib-sources.jar"
    if [ ! -r "$stdlibJar" ]; then
      stdlibJar="${kotlin}/lib/kotlin-stdlib.jar"
      stdlibSources="${kotlin}/lib/kotlin-stdlib-sources.jar"
    fi

    m2="$HOME/.m2/repository/org/jetbrains/kotlin/kotlin-stdlib/${wizardStdlibVersion}"
    install -d "$m2"
    install -m 644 "$stdlibJar" "$m2/kotlin-stdlib-${wizardStdlibVersion}.jar"
    install -m 644 ${stdlibPom} "$m2/kotlin-stdlib-${wizardStdlibVersion}.pom"
    if [ -r "$stdlibSources" ]; then
      install -m 644 "$stdlibSources" "$m2/kotlin-stdlib-${wizardStdlibVersion}-sources.jar"
    fi

    printf '%s\n' \
      'kotlin-stdlib-${wizardStdlibVersion}.jar>=' \
      'kotlin-stdlib-${wizardStdlibVersion}.pom>=' \
      > "$m2/_remote.repositories"
    rm -f "$m2"/*.lastUpdated
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.jetbrains.enable && langs.kotlin.enable) {
    home.activation.ideaKotlinStdlib = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${seedStdlib}
    '';
  };
}
