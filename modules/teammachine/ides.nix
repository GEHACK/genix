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

    # IntelliJ IDEA, wrapped exactly like pycharmAutoDetect above. The FHS env
    # additionally exposes jdk21 and the kotlin toolchain so IDEA can compile
    # and run Kotlin code without internet access.
    ideaAutoDetect =
      let
        ideaBin = pkgs.jetbrains.idea.meta.mainProgram;
      in
      pkgs.buildFHSEnv {
        name = "idea-with-kotlin";

        targetPkgs = pkgs: [
          pkgs.jetbrains.idea
          pkgs.jdk21
          pkgs.kotlin
        ];

        runScript = ideaBin;

        extraInstallCommands = ''
          mkdir -p $out/bin $out/share/applications

          if [ -d ${pkgs.jetbrains.idea}/share/icons ]; then
            ln -s ${pkgs.jetbrains.idea}/share/icons $out/share/icons
          fi
          if [ -d ${pkgs.jetbrains.idea}/share/pixmaps ]; then
            ln -s ${pkgs.jetbrains.idea}/share/pixmaps $out/share/pixmaps
          fi

          cp ${pkgs.jetbrains.idea}/share/applications/*.desktop $out/share/applications/
          chmod +w $out/share/applications/*.desktop

          # Point the desktop file to our new FHS wrapper
          sed -i "s|Exec=${ideaBin}|Exec=$out/bin/idea-with-kotlin|g" $out/share/applications/*.desktop
          sed -i "s|Exec=${pkgs.jetbrains.idea}/bin/${ideaBin}|Exec=$out/bin/idea-with-kotlin|g" $out/share/applications/*.desktop
        '';
      };

in 
{
  environment.systemPackages = with pkgs; [ 
    pycharmAutoDetect 
    ideaAutoDetect
    jetbrains.clion 
    eclipses.eclipse-java 
    vim 
    nano 
    neovim 
    emacs 
    netbeans

    gedit

    geany 
    xterm #Necessary for geany
    
    codeblocksFull 
  ];
}
