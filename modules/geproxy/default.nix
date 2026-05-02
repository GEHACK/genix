{ pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./cuproxy.nix
    ./devdocs.nix
    ./fog.nix
    ./networking.nix
    ./ntp.nix
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
