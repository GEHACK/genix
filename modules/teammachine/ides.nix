{ config, pkgs, ... }: {
    environment.systemPackages = with pkgs; [ 
        jetbrains.pycharm
        jetbrains.idea
        jetbrains.clion
        eclipses.eclipse-java
        # vscode met plugins
        vim
        nano
        neovim
        emacs
        gedit
        geany
        kdePackages.kate
    ];
}