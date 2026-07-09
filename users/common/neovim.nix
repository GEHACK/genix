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

  grammars =
    with pkgs.vimPlugins.nvim-treesitter.builtGrammars;
    lib.optional (langs.c.enable) c
    ++ lib.optional (langs.cpp.enable) cpp
    ++ lib.optional (langs.python.enable) python
    ++ lib.optional (langs.java.enable) java
    ++ lib.optional (langs.kotlin.enable) kotlin;
in
{
  options.teammachine.neovim.enable =
    lib.mkEnableOption "Neovim (nixvim) with contest LSP/treesitter";

  config.programs.nixvim = lib.mkIf config.teammachine.neovim.enable {
    enable = true;
    nixpkgs.source = pkgs.path;

    viAlias = false;
    vimAlias = false;

    extraPackages = [ pkgs.tree-sitter ];

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      number = true;
      expandtab = true;
      shiftwidth = 4;
      tabstop = 4;
    };

    plugins = {
      web-devicons.enable = true;
      which-key.enable = true;
      neo-tree.enable = true;

      lsp = lib.mkIf anyLangEnabled {
        enable = true;
        servers = {
          clangd.enable = langs.c.enable || langs.cpp.enable;
          pyright.enable = langs.python.enable;
          jdtls.enable = langs.java.enable;
          kotlin_language_server = lib.mkIf langs.kotlin.enable {
            enable = true;
            package = pkgs.kotlin-language-server;
          };
        };
      };

      treesitter = lib.mkIf anyLangEnabled {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
        grammarPackages = grammars;
      };
    };

    keymaps =
      [
        {
          mode = "n";
          key = "<leader>e";
          action = "<cmd>Neotree toggle<cr>";
          options = {
            silent = true;
            desc = "Toggle file tree";
          };
        }
      ]
      ++ lib.optionals anyLangEnabled [
        { mode = "n"; key = "gd"; action.__raw = "vim.lsp.buf.definition"; options.silent = true; }
        { mode = "n"; key = "gr"; action.__raw = "vim.lsp.buf.references"; options.silent = true; }
        { mode = "n"; key = "K";  action.__raw = "vim.lsp.buf.hover"; options.silent = true; }
        { mode = "n"; key = "<leader>rn"; action.__raw = "vim.lsp.buf.rename"; options.silent = true; }
        { mode = "n"; key = "<leader>ca"; action.__raw = "vim.lsp.buf.code_action"; options.silent = true; }
        { mode = "n"; key = "[d"; action.__raw = "vim.diagnostic.goto_prev"; options.silent = true; }
        { mode = "n"; key = "]d"; action.__raw = "vim.diagnostic.goto_next"; options.silent = true; }
      ];
  };
}
