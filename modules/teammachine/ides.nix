{ config, pkgs, ... }: 
let 
    pycharmAutoDetect = pkgs.buildFHSEnv {
      name = "pycharm-with-python";
      
      # This maps Python and PyCharm into standard Linux paths (like /usr/bin)
      targetPkgs = pkgs: [
        pkgs.jetbrains.pycharm
        pkgs.python3
      ];
      
      # The command to execute when the sandbox starts
      runScript = "pycharm";
      
      # Recreate the desktop launcher and icons so your App Menu works
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
        
        # Point the desktop file to our new FHS wrapper
        sed -i "s|Exec=pycharm|Exec=$out/bin/pycharm-with-python|g" $out/share/applications/*.desktop
        sed -i "s|Exec=${pkgs.jetbrains.pycharm}/bin/pycharm|Exec=$out/bin/pycharm-with-python|g" $out/share/applications/*.desktop
      '';
    };

in 
{
  environment.systemPackages = with pkgs; [ 
    pycharmAutoDetect 
    jetbrains.idea
    jetbrains.clion 
    eclipses.eclipse-java 
    vim 
    nano 
    neovim 
    emacs 

    gedit

    geany 
    xterm #Necessary for geany

    kdePackages.kate #Kate crashes if started from launchpad, does not crash if started from console?!
    codeblocksFull 
  ];
}
