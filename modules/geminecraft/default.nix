{ pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./imaged.nix
    ./minecraft.nix
    ./networking.nix
    ./pxe.nix
    ./traefik.nix
  ];

  environment.systemPackages = with pkgs; [
    wget
    unzip
    btop
    git
  ];
}
