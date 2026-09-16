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
  jdk = pkgs.jdk21;

  ideaOptions = ".config/JetBrains/IntelliJIdea${lib.versions.majorMinor idea.version}/options";

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

  # IDEA registers no JDK of its own except the runtime it ships with, so a fresh
  # profile puts every new project on jbr-25 with no SDK roots: Java resolution and
  # javac are dead and the Kotlin compiler has no JVM target. Registering the
  # contest JDK is the only way to pin the wizard, and the SDK is unusable unless
  # every module root is spelled out (an entry with empty roots is reported as
  # "Project JDK is misconfigured").
  seedJdkTable = pkgs.writeShellScript "idea-jdk-table" ''
    set -euo pipefail

    jdk=${jdk.home}
    version=$(sed -n 's/^JAVA_VERSION="\(.*\)"$/\1/p' "$jdk/release")
    modules=$(sed -n 's/^MODULES="\(.*\)"$/\1/p' "$jdk/release")

    install -d "$1"
    {
      printf '%s\n' \
        '<application>' \
        '  <component name="ProjectJdkTable">' \
        '    <jdk version="2">' \
        '      <name value="${lib.versions.major jdk.version}" />' \
        '      <type value="JavaSDK" />' \
        "      <version value=\"Java $version\" />" \
        "      <homePath value=\"$jdk\" />" \
        '      <roots>' \
        '        <annotationsPath>' \
        '          <root type="composite">' \
        '            <root url="jar://$APPLICATION_HOME_DIR$/plugins/java/lib/resources/jdkAnnotations.jar!/" type="simple" />' \
        '          </root>' \
        '        </annotationsPath>' \
        '        <classPath>' \
        '          <root type="composite">'
      for module in $modules; do
        printf '            <root url="jrt://%s!/%s" type="simple" />\n' "$jdk" "$module"
      done
      printf '%s\n' \
        '          </root>' \
        '        </classPath>' \
        '        <javadocPath>' \
        '          <root type="composite" />' \
        '        </javadocPath>' \
        '        <sourcePath>' \
        '          <root type="composite">'
      for module in $modules; do
        printf '            <root url="jar://%s/lib/src.zip!/%s" type="simple" />\n' "$jdk" "$module"
      done
      printf '%s\n' \
        '          </root>' \
        '        </sourcePath>' \
        '      </roots>' \
        '      <additional />' \
        '    </jdk>' \
        '  </component>' \
        '</application>'
    } > "$1/jdk.table.xml"
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.jetbrains.enable && (langs.java.enable || langs.kotlin.enable)) {
    home.activation = {
      ideaJdkTable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${seedJdkTable} "$HOME/${ideaOptions}"
      '';
    }
    // lib.optionalAttrs langs.kotlin.enable {
      ideaKotlinStdlib = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${seedStdlib}
      '';
    };
  };
}
