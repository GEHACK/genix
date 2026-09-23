{
  pkgs,
  ...
}:
{
  imports = [
    ./options.nix
    ./firefox.nix
    ./neovim.nix
    ./trackpad.nix
    ./zsh.nix
  ];
  home.packages = with pkgs; [
    btop
    htop
    git
    wget
    curl
    zip
    unzip
  ];
}
