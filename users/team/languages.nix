{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.teammachine.languages;
  toolchain = pkgs.contestToolchain;
  flags = import ./compile-flags.nix;

  mygcc = pkgs.writeShellScriptBin "mygcc" ''
    ${toolchain.gcc}/bin/gcc ${flags.c} \
      -o "$1" "$1.c" -lm
  '';

  mygpp = pkgs.writeShellScriptBin "mygpp" ''
    ${toolchain.gcc}/bin/g++ ${flags.cpp} \
      -o "$1" "$1.cpp" -lm
  '';

  mypython = pkgs.writeShellScriptBin "mypython" ''
    exec ${toolchain.pypy3}/bin/pypy3 "$@"
  '';

  myjavac = pkgs.writeShellScriptBin "myjavac" ''
    exec ${toolchain.jdk}/bin/javac -encoding UTF-8 -sourcepath . -d . "$@"
  '';

  mykotlinc = pkgs.writeShellScriptBin "mykotlinc" ''
    exec ${toolchain.kotlin}/bin/kotlinc -d . "$@"
  '';
in
{
  home.packages =
    lib.optionals cfg.c.enable [
      toolchain.gcc
      pkgs.gdb
      pkgs.cmake
      mygcc
    ]
    ++ lib.optionals cfg.cpp.enable [
      toolchain.gcc
      pkgs.gdb
      pkgs.cmake
      mygpp
    ]
    ++ lib.optionals cfg.python.enable [
      (toolchain.pypy3.withPackages (pypy-pkgs: [ ]))
      (pkgs.python3.withPackages (python-pkgs: [ ]))
      mypython
    ]
    ++ lib.optionals cfg.java.enable [
      toolchain.jdk
      myjavac
    ]
    ++ lib.optionals cfg.kotlin.enable [
      toolchain.kotlin
      toolchain.jdk
      mykotlinc
    ];

  home.sessionVariables = lib.mkIf (cfg.java.enable || cfg.kotlin.enable) {
    JAVA_HOME = "${toolchain.jdk.home}";
  };
}
