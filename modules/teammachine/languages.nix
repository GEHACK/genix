{ config, pkgs, ... }:

let
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
  environment.systemPackages = with pkgs; [ 
    jdk21
    (pypy3.withPackages (pypy-pkgs: [
    # pypy-pkgs.numpy
    # pypy-pkgs.scipy
    ]))  
    (python3.withPackages (python-pkgs: [
    # python-pkgs.numpy
    # python-pkgs.scipy
    ]))
    gcc
    gdb
    cmake
    kotlin

    mygcc
    mygpp
    mypython
    myjavac
    mykotlinc
  ];
}