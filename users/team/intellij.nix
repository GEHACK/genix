{ pkgs, lib, ... }:

# Offline Kotlin support for IntelliJ IDEA Community.
#
# Contestants have no internet access, so when they open a Kotlin file IDEA's
# "Configure Kotlin in Project" button cannot download kotlin-stdlib from
# Maven Central. Selecting the "IntelliJ IDEA" build system asks IDEA to use
# an application-level library named "KotlinJavaRuntime"; if that library is
# missing IDEA tries to create it by copying jars, which can fail in the
# read-only FHS-wrapped IDEA we use.
#
# We pre-seed that library here, pointing at the kotlin toolchain installed
# via Nix. After this, "Configure Kotlin -> IntelliJ IDEA build system" just
# attaches the existing library to the module — fully offline.

let
  kotlinLib = "${pkgs.kotlin}/lib/kotlin/lib";

  # Jars that make up the Kotlin runtime for an IDEA module. These names are
  # stable across recent kotlin releases in nixpkgs.
  jars = [
    "kotlin-stdlib.jar"
    "kotlin-stdlib-jdk7.jar"
    "kotlin-stdlib-jdk8.jar"
    "kotlin-reflect.jar"
    "kotlin-test.jar"
  ];

  jarRootEntries = lib.concatMapStringsSep "\n          "
    (j: ''<root url="jar://${kotlinLib}/${j}!/" />'') jars;

  jarSrcEntries = lib.concatMapStringsSep "\n          "
    (j: ''<root url="jar://${kotlinLib}/${j}!/" />'') jars;

  applicationLibrariesXml = ''
    <application>
      <component name="libraryTable">
        <library name="KotlinJavaRuntime">
          <CLASSES>
          ${jarRootEntries}
          </CLASSES>
          <JAVADOC />
          <SOURCES>
          ${jarSrcEntries}
          </SOURCES>
        </library>
      </component>
    </application>
  '';

  # IDEA's per-version config directory uses the major.minor of the IDE
  # version, e.g. "2024.3" for 2024.3.1.1.
  ideaVersion = pkgs.jetbrains.idea.version;
  configMajorMinor =
    lib.concatStringsSep "." (lib.take 2 (lib.splitString "." ideaVersion));

  configDir = ".config/JetBrains/IdeaIC${configMajorMinor}";
in
{
  # Drop the applicationLibraries.xml into the expected config dir. If the
  # user has never launched IDEA before, this just pre-creates the dir.
  home.file."${configDir}/options/applicationLibraries.xml".text =
    applicationLibrariesXml;
}
