{
  pkgs,
  ...
}: {
  imports = [
    ./options.nix
    ./firefox.nix
    ./neovim.nix
  ];
  home.packages = with pkgs; [
    btop
    htop
  ];
}
