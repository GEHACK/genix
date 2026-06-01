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
  options.teammachine.languages = {
    c.enable = lib.mkEnableOption "C toolchain" // {
      default = false;
    };
    cpp.enable = lib.mkEnableOption "C++ toolchain" // {
      default = false;
    };
    python.enable = lib.mkEnableOption "Python toolchain" // {
      default = false;
    };
    java.enable = lib.mkEnableOption "Java toolchain" // {
      default = false;
    };
    kotlin.enable = lib.mkEnableOption "Kotlin toolchain" // {
      default = false;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.java.enable {
      programs.java = {
        enable = true;
        package = pkgs.jdk21;
      };
    })
    {
      environment.systemPackages =
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
        ++ lib.optionals cfg.java.enable [ myjavac ]
        ++ lib.optionals cfg.kotlin.enable [
          pkgs.kotlin
          mykotlinc
        ];
    }
  ];
}
