{ pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./cuproxy.nix
    ./fog.nix
    ./networking.nix
    ./traefik.nix
  ];

  environment.systemPackages = with pkgs; [
    wget

    zip
    unzip

    btop
    htop

    git
  ];
}
