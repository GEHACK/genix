{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.teammachine.misc-packages.enable =
    lib.mkEnableOption "assorted CLI utilities (from the NAC26 image)";

  config = lib.mkIf config.teammachine.misc-packages.enable {
    home.packages = with pkgs; [
      # Debugging and profiling
      valgrind
      strace
      shellcheck

      # Multiplexer
      tmux
      screen

      # CLI downloading
      wget

      # Zipping and unzipping
      zip
      unzip
      p7zip

      # Monitoring
      btop
      htop
      iotop
      sysstat

      # Version control
      git
    ];
  };
}
