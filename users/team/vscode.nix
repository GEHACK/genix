{ pkgs, ... } : {
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;
    profiles.default = {
      userSettings = {
        "chat.disableAIFeatures" = true;
      }; 
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        ms-python.vscode-pylance
        ms-python.debugpy
        redhat.java
        vscjava.vscode-java-debug
        vscjava.vscode-java-test
        ms-vscode.cpptools
        ms-vscode.cmake-tools
        vscodevim.vim
      ];
    }; 
  }; 

  xdg.desktopEntries = {
    "code-novim" = {
      name = "Visual Studio Code";
      genericName = "Text Editor";
      exec = "code --disable-extension vscodevim.vim %F";
      icon = "vscode"; 
      terminal = false;
      startupNotify = true;
      categories = [ "Utility" "TextEditor" "Development" "IDE" ];
      mimeType = [ "text/plain" "inode/directory" ];
    };

    "code" = {
      name = "Visual Studio Code (with vim bindings!)";
      genericName = "Text Editor";
      exec = "code %F"; 
      icon = "vscode"; 
      terminal = false;
      startupNotify = true;
      categories = [ "Utility" "TextEditor" "Development" "IDE" ];
      mimeType = [ "text/plain" "inode/directory" ];
    };
  };
}