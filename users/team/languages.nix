{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.teammachine.languages;
  staticGlibc = pkgs.glibc.static;

  mygcc = pkgs.writeShellScriptBin "mygcc" ''
    ${pkgs.gcc}/bin/gcc -std=gnu17 -x c -Wall -O2 -static -pipe \
      -L${staticGlibc}/lib \
      -o "$1" "$1.c" -lm
  '';

  mygpp = pkgs.writeShellScriptBin "mygpp" ''
    ${pkgs.gcc}/bin/g++ -std=gnu++20 -x c++ -Wall -O2 -static -pipe \
      -L${staticGlibc}/lib \
      -o "$1" "$1.cpp" -lm
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
in
{
  home.packages =
    lib.optionals cfg.c.enable [
      pkgs.gcc
      pkgs.gdb
      pkgs.cmake
      mygcc
    ]
    ++ lib.optionals cfg.cpp.enable [
      pkgs.gcc
      pkgs.gdb
      pkgs.cmake
      mygpp
    ]
    ++ lib.optionals cfg.python.enable [
      (pkgs.pypy3.withPackages (pypy-pkgs: [ ]))
      (pkgs.python3.withPackages (python-pkgs: [ ]))
      mypython
    ]
    ++ lib.optionals cfg.java.enable [
      pkgs.jdk21
      myjavac
    ]
    ++ lib.optionals cfg.kotlin.enable [
      pkgs.kotlin
      mykotlinc
    ];

  home.sessionVariables = lib.mkIf cfg.java.enable {
    JAVA_HOME = "${pkgs.jdk21}";
  };
}
