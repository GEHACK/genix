{ lib, ... }:
{
  options.teammachine.languages = {
    c.enable = lib.mkEnableOption "C toolchain";
    cpp.enable = lib.mkEnableOption "C++ toolchain";
    python.enable = lib.mkEnableOption "Python toolchain";
    java.enable = lib.mkEnableOption "Java toolchain";
    kotlin.enable = lib.mkEnableOption "Kotlin toolchain";
  };
}
