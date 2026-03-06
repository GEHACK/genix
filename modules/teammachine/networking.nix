{ pkgs, ... }: {
  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts = 
      ''
        127.0.0.1 docs
        10.0.0.1 judge
      '';

    # Disable the default iptables-based firewall manager
    firewall.enable = false;

    # Enable native nftables and provide the raw ruleset
    nftables = {
      enable = true;
      checkRuleset = true;
      rulesetFile = ./assets/firewall.nft;
    };
  };
  
  boot.blacklistedKernelModules = [ "iwlwifi" "btusb" ];
}