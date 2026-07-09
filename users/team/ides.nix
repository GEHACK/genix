{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.teammachine.ides;
  langs = config.teammachine.languages;

  pycharmAutoDetect = pkgs.buildFHSEnv {
    name = "pycharm-with-python";

    targetPkgs = pkgs: [
      pkgs.jetbrains.pycharm
      pkgs.python3
    ];

    runScript = "pycharm";

    extraInstallCommands = ''
      mkdir -p $out/bin $out/share/applications

      if [ -d ${pkgs.jetbrains.pycharm}/share/icons ]; then
        ln -s ${pkgs.jetbrains.pycharm}/share/icons $out/share/icons
      fi
      if [ -d ${pkgs.jetbrains.pycharm}/share/pixmaps ]; then
        ln -s ${pkgs.jetbrains.pycharm}/share/pixmaps $out/share/pixmaps
      fi

      cp ${pkgs.jetbrains.pycharm}/share/applications/*.desktop $out/share/applications/
      chmod +w $out/share/applications/*.desktop

      sed -i "s|Exec=pycharm|Exec=$out/bin/pycharm-with-python|g" $out/share/applications/*.desktop
      sed -i "s|Exec=${pkgs.jetbrains.pycharm}/bin/pycharm|Exec=$out/bin/pycharm-with-python|g" $out/share/applications/*.desktop
    '';
  };
in
{
  options.teammachine.ides = {
    enable = lib.mkEnableOption "graphical editors and IDEs";
    jetbrains.enable = lib.mkEnableOption "JetBrains IDEs (PyCharm/IDEA/CLion)";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      # Lightweight editors, always present when IDEs are enabled.
      (with pkgs; [
        vim
        nano
        emacs
        gedit
        geany
        xterm
      ])
      ++ lib.optionals (langs.python.enable && cfg.jetbrains.enable) [ pycharmAutoDetect ]
      ++ lib.optionals (langs.java.enable && cfg.jetbrains.enable) [ pkgs.jetbrains.idea ]
      ++ lib.optionals (langs.kotlin.enable && cfg.jetbrains.enable) [ pkgs.jetbrains.idea ]
      ++ lib.optionals (langs.cpp.enable && cfg.jetbrains.enable) [ pkgs.jetbrains.clion ]
      ++ lib.optionals langs.java.enable (with pkgs; [
        eclipses.eclipse-java
        netbeans
      ])
      ++ lib.optionals langs.cpp.enable [ pkgs.codeblocksFull ]
      ++ lib.optionals langs.c.enable [ pkgs.codeblocksFull ];
  };
}
