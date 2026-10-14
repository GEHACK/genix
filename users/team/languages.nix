{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.teammachine.languages;
  toolchain = import ../../toolchain { inherit pkgs; };
  inherit (toolchain) compilers helpers;
in
{
  home.packages =
    lib.optionals cfg.c.enable (
      compilers.c
      ++ [
        pkgs.gdb
        pkgs.cmake
        helpers.mygcc
      ]
    )
    ++ lib.optionals cfg.cpp.enable (
      compilers.cpp
      ++ [
        pkgs.gdb
        pkgs.cmake
        helpers.mygpp
      ]
    )
    ++ lib.optionals cfg.python.enable [
      (pkgs.pypy3.withPackages (pypy-pkgs: [ ]))
      (pkgs.python3.withPackages (python-pkgs: [ ]))
      helpers.mypython
    ]
    ++ lib.optionals cfg.java.enable (compilers.java ++ [ helpers.myjavac ])
    ++ lib.optionals cfg.kotlin.enable (compilers.kotlin ++ [ helpers.mykotlinc ]);

  home.sessionVariables = lib.mkIf (cfg.java.enable || cfg.kotlin.enable) {
    JAVA_HOME = "${pkgs.jdk21.home}";
  };
}
