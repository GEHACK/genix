{
  config,
  pkgs,
  lib,
  ...
}:
let
  langs = config.teammachine.languages;

  anyLangEnabled =
    langs.c.enable
    || langs.cpp.enable
    || langs.python.enable
    || langs.java.enable
    || langs.kotlin.enable;

  cEnabled = langs.c.enable || langs.cpp.enable;
in
{
  config = lib.mkIf anyLangEnabled {
    programs.vscode = {
      enable = true;
      mutableExtensionsDir = false;
      profiles.default = {
        userSettings = {
          "chat.disableAIFeatures" = true;

          # C/C++ compiler & IntelliSense
          "C_Cpp.default.compilerPath" = "${pkgs.gcc}/bin/g++";
          "C_Cpp.default.cStandard" = "c17";
          "C_Cpp.default.cppStandard" = "c++23";
          "C_Cpp.default.intelliSenseMode" = "linux-gcc-x64";

          # compiler args surfaced in IntelliSense
          "C_Cpp.default.compilerArgs" = [
            "-Wall"
            "-Wextra"
            "-Wpedantic"
            "-g" # debug symbols
          ];
        };
        extensions =
          with pkgs.vscode-extensions;
          lib.optionals langs.python.enable [
            ms-python.python
            ms-python.vscode-pylance
            ms-python.debugpy
          ]
          ++ lib.optionals langs.java.enable [
            redhat.java
            vscjava.vscode-java-debug
            vscjava.vscode-java-test
          ]
          ++ lib.optionals cEnabled [
            ms-vscode.cpptools
            ms-vscode.cmake-tools
          ]
          ++ [ vscodevim.vim ];
      };
    };

    xdg.configFile = lib.mkIf cEnabled {
      "Code/User/tasks.json".text = builtins.toJSON {
        version = "2.0.0";
        tasks = [
          {
            label = "g++: build active file";
            type = "shell";
            command = "${pkgs.gcc}/bin/g++";
            args = [
              "-std=c++23"
              "-Wall"
              "-Wextra"
              "-Wpedantic"
              "-g"
              "\${file}"
              "-o"
              "\${fileDirname}/\${fileBasenameNoExtension}"
            ];
            group = {
              kind = "build";
              isDefault = true;
            };
            detail = "compile the open file with g++";
            problemMatcher = [ "\$gcc" ];
          }
          {
            label = "gcc: build active file (C)";
            type = "shell";
            command = "${pkgs.gcc}/bin/gcc";
            args = [
              "-std=c17"
              "-Wall"
              "-Wextra"
              "-Wpedantic"
              "-g"
              "\${file}"
              "-o"
              "\${fileDirname}/\${fileBasenameNoExtension}"
            ];
            group = "build";
            detail = "compile the open file with gcc (plain C)";
            problemMatcher = [ "\$gcc" ];
          }
        ];
      };

      "Code/User/launch.json".text = builtins.toJSON {
        version = "0.2.0";
        configurations = [
          {
            name = "g++: debug active file";
            type = "cppdbg";
            request = "launch";
            program = "\${fileDirname}/\${fileBasenameNoExtension}";
            args = [ ];
            stopAtEntry = false;
            cwd = "\${fileDirname}";
            environment = [ ];
            externalConsole = false;
            MIMode = "gdb";
            miDebuggerPath = "${pkgs.gdb}/bin/gdb";
            setupCommands = [
              {
                description = "enable pretty-printing";
                text = "-enable-pretty-printing";
                ignoreFailures = true;
              }
              {
                description = "set disassembly flavour to intel";
                text = "-gdb-set disassembly-flavor intel";
                ignoreFailures = true;
              }
            ];
            preLaunchTask = "g++: build active file";
          }
        ];
      };
    };

    xdg.desktopEntries = {
      "code-novim" = {
        name = "VScode";
        genericName = "Text Editor";
        exec = "code --disable-extension vscodevim.vim %F";
        icon = "vscode";
        terminal = false;
        startupNotify = true;
        categories = [
          "Utility"
          "TextEditor"
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "inode/directory"
        ];
      };
      "code" = {
        name = "VScode (vim)";
        genericName = "Text Editor";
        exec = "code %F";
        icon = builtins.path {
          path = ../../assets/vscode-vim.png;
          name = "vscode-vim.png";
        };
        terminal = false;
        startupNotify = true;
        categories = [
          "Utility"
          "TextEditor"
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "inode/directory"
        ];
      };
    };
  };
}
