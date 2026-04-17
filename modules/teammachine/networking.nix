{ pkgs, judge_ip, contest_subnet, ... }: {
  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts =
      ''
        127.0.0.1 docs
        ${judge_ip} judge
      '';

    # Disable the default iptables-based firewall manager
    firewall.enable = false;

    # Enable native nftables and provide the raw ruleset
    nftables = {
      enable = true;
      checkRuleset = true;
      ruleset = ''
        flush ruleset
        table inet filter {
            chain input {
                type filter hook input priority filter; policy accept;
                iifname "lo" accept
                ip saddr ${judge_ip} accept
                ip saddr ${contest_subnet} drop
            }

            chain forward {
                type filter hook forward priority filter; policy drop;
            }

            chain output {
                type filter hook output priority filter; policy accept;
                oifname "lo" accept
                ip daddr ${judge_ip} accept
                ip daddr ${contest_subnet} drop
            }
        }
      '';
    };
  };
  
  boot.blacklistedKernelModules = [ "iwlwifi" "btusb" ];
}