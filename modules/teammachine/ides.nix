{ config, pkgs, lib, ... }:
let
  cfg = config.teammachine.languages;

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
  environment.systemPackages =
    (with pkgs; [
      vim
      nano
      neovim
      emacs
      gedit
      geany
      xterm
    ])
    ++ lib.optionals cfg.python.enable [ pycharmAutoDetect ]
    ++ lib.optionals cfg.java.enable (with pkgs; [
      jetbrains.idea
      eclipses.eclipse-java
      netbeans
    ])
    ++ lib.optionals cfg.kotlin.enable [ pkgs.jetbrains.idea ]
    ++ lib.optionals cfg.cpp.enable (with pkgs; [
      jetbrains.clion
      codeblocksFull
    ])
    ++ lib.optionals cfg.c.enable [ pkgs.codeblocksFull ];
}
