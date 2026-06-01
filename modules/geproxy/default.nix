{ pkgs, lib, config, loom_url, ... }:
let
  operatorKeys = lib.pipe ../../authorized_keys [
    builtins.readFile
    (lib.splitString "\n")
    (map lib.strings.trim)
    (lib.filter (l: l != "" && !(lib.hasPrefix "#" l)))
  ];
in
{
  imports = [
    ./balloons.nix
    ./boot.nix
    ./cuproxy.nix
    ./devdocs.nix
    ./fanout.nix
    ./fog.nix
    ./networking.nix
    ./ntp.nix
    ./traefik.nix
  ];

  sops.secrets.fanout-ssh-key = {
    owner = "deploy";
    group = "deploy";
    mode = "0400";
  };

  services.buildFanout = {
    enable = true;
    inventoryUrl = "${loom_url}/api/inventory";
    sshKeyFile = config.sops.secrets.fanout-ssh-key.path;
    authorizedKeys = operatorKeys;
  };

  environment.systemPackages = with pkgs; [
    wget

    zip
    unzip

    btop
    htop

    git
  ];
}
