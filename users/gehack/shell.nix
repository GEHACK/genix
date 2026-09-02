{ pkgs, ... }:
{
  programs = {
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      antidote = {
        enable = true;
        plugins = [
          "getantidote/use-omz"
          "ohmyzsh/ohmyzsh path:lib"
        ];
      };
      initContent = ''
        DISABLE_AUTO_UPDATE="true"
        fpath+=("${pkgs.pure-prompt}/share/zsh/site-functions")
        autoload -Uz promptinit; promptinit
        prompt pure
      '';
    };
    vim.enable = true;
  };
}
