# Single definition of the contest toolchain, consumed by the teammachines
# (users/team/languages.nix) and the judgehost chroot (modules/judgehost/judgedaemon.nix).
# Both get pkgs with toolchain/overlay.nix applied, so both resolve to the same store paths.
{ pkgs }:
let
  inherit (pkgs) lib;

  flags = {
    c = [
      "-std=gnu17"
      "-x"
      "c"
      "-Wall"
      "-O2"
      "-static"
      "-pipe"
    ];
    cpp = [
      "-std=gnu++20"
      "-x"
      "c++"
      "-Wall"
      "-O2"
      "-static"
      "-pipe"
    ];
  };

  # Nix's gcc wrapper doesn't know about glibc.static, so plain `gcc -static` fails.
  staticAware =
    name:
    lib.hiPrio (
      pkgs.writeShellScriptBin name ''
        for arg in "$@"; do
          if [ "$arg" = -static ]; then
            exec ${pkgs.gcc}/bin/${name} "$@" -L${pkgs.glibc.static}/lib
          fi
        done
        exec ${pkgs.gcc}/bin/${name} "$@"
      ''
    );

  gcc = staticAware "gcc";
  gpp = staticAware "g++";

  compilers = {
    c = [
      pkgs.gcc
      gcc
    ];
    cpp = [
      pkgs.gcc
      gpp
    ];
    python = [ pkgs.pypy3 ];
    java = [ pkgs.jdk21 ];
    kotlin = [
      pkgs.kotlin
      pkgs.jdk21
    ];
  };

  args = lib.escapeShellArgs;

  # Commands shared by the teammachine helpers and the DOMjudge compile scripts.
  compileCmd = {
    c = out: src: ''gcc ${args flags.c} -o ${out} ${src} -lm'';
    cpp = out: src: ''g++ ${args flags.cpp} -o ${out} ${src}'';
  };

  helpers = {
    mygcc = pkgs.writeShellScriptBin "mygcc" ''
      PATH=${gcc}/bin:$PATH
      ${compileCmd.c ''"$1"'' ''"$1.c"''}
    '';
    mygpp = pkgs.writeShellScriptBin "mygpp" ''
      PATH=${gpp}/bin:$PATH
      ${compileCmd.cpp ''"$1"'' ''"$1.cpp"''}
    '';
    mypython = pkgs.writeShellScriptBin "mypython" ''
      exec ${pkgs.pypy3}/bin/pypy3 "$@"
    '';
    myjavac = pkgs.writeShellScriptBin "myjavac" ''
      exec ${pkgs.jdk21}/bin/javac -encoding UTF-8 -sourcepath . -d . "$@"
    '';
    mykotlinc = pkgs.writeShellScriptBin "mykotlinc" ''
      exec ${pkgs.kotlin}/bin/kotlinc -d . "$@"
    '';
  };

  # Everything the DOMjudge compile/run scripts call by name.
  judgeEnv = pkgs.buildEnv {
    name = "judge-toolchain";
    paths =
      lib.unique (lib.flatten (lib.attrValues compilers))
      ++ (with pkgs; [
        bash
        coreutils
        findutils
        gnugrep
        gnused
        gawk
      ]);
  };

  # Replaces dj_make_chroot. chroot-startstop.sh needs etc/usr/lib/bin/lib64 to exist;
  # symlinks are recreated as-is in each judging dir and resolve through the bind-mounted nix/.
  chroot = pkgs.runCommand "domjudge-chroot" { } ''
    mkdir -p $out/nix/store $out/etc $out/lib
    xargs -a ${pkgs.closureInfo { rootPaths = [ judgeEnv ]; }}/store-paths cp -a -t $out/nix/store
    ln -s ${judgeEnv} $out/usr
    ln -s usr/bin $out/bin
    ln -s lib $out/lib64
  '';

  compileScript =
    cmd:
    pkgs.writeText "run" ''
      #!/bin/sh
      DEST="$1" ; shift
      MEMLIMIT="$1" ; shift
      ${cmd}
    '';

  # Upload to the domserver as the c/cpp executables. Other languages use DOMjudge's defaults.
  executables = pkgs.runCommand "domjudge-executables" { nativeBuildInputs = [ pkgs.zip ]; } ''
    mkdir -p $out
    for lang in c cpp; do
      mkdir -p work/$lang
    done
    install -m 755 ${compileScript (compileCmd.c ''"$DEST"'' ''"$@"'')} work/c/run
    install -m 755 ${compileScript (compileCmd.cpp ''"$DEST"'' ''"$@"'')} work/cpp/run
    for lang in c cpp; do
      touch -t 198001010000 work/$lang/run
      (cd work/$lang && zip -q -X $out/$lang.zip run)
    done
  '';
in
{
  inherit
    flags
    compilers
    helpers
    judgeEnv
    chroot
    executables
    ;
}
