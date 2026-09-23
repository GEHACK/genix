{
  lib,
  config,
  loom_url,
  ...
}:
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
    ./cds.nix
    ./cuproxy.nix
    ./ddns.nix
    ./devdocs.nix
    ./fanout.nix
    ./imaged.nix
    ./network
    ./ntp.nix
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
    sshOpts = [
      "-o"
      "UserKnownHostsFile=/dev/null"
      "-o"
      "GlobalKnownHostsFile=/dev/null"
      "-o"
      "StrictHostKeyChecking=no"
    ];
  };
}
