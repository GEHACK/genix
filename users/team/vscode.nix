{ pkgs, ... } : {
  programs.vscode = {
    enable = true;
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
}