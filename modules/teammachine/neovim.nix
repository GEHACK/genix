{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.teammachine.languages;

  anyLangEnabled =
    cfg.c.enable
    || cfg.cpp.enable
    || cfg.python.enable
    || cfg.java.enable
    || cfg.kotlin.enable;

  grammars = with pkgs.vimPlugins.nvim-treesitter.builtGrammars;
    lib.optional (cfg.c.enable) c
    ++ lib.optional (cfg.cpp.enable) cpp
    ++ lib.optional (cfg.python.enable) python
    ++ lib.optional (cfg.java.enable) java
    ++ lib.optional (cfg.kotlin.enable) kotlin;
in
{
  programs.nixvim = {
    enable = true;
    nixpkgs.source = pkgs.path;

    viAlias = false;
    vimAlias = false;

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
          clangd.enable = cfg.c.enable || cfg.cpp.enable;
          pyright.enable = cfg.python.enable;
          jdtls.enable = cfg.java.enable;
          kotlin_language_server = lib.mkIf cfg.kotlin.enable {
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
        { mode = "n"; key = "<leader>e"; action = "<cmd>Neotree toggle<cr>"; options = { silent = true; desc = "Toggle file tree"; }; }
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
