{
  config,
  lib,
  pkgs,
  geproxy_ip,
  contest_subnet,
  cds_port,
  ...
}:
let
  inherit (config.teammachine.geproxy) discover host;

  geproxy = if discover then "@geproxy" else geproxy_ip;
in
{

  environment.systemPackages = with pkgs; [
    wakeonlan
  ];

  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts = lib.optionalString (!discover) ''
      ${geproxy_ip} judge
    '';

    interfaces.enp0s31f6.wakeOnLan.enable = true;

    # Disable the default iptables-based firewall manager
    firewall.enable = false;

    # Enable native nftables and provide the raw ruleset
    nftables = {
      enable = true;
      checkRuleset = true;
      ruleset = ''
        flush ruleset
        table inet filter {
            ${lib.optionalString discover "set geproxy { type ipv4_addr; }"}

            chain input {
                type filter hook input priority filter; policy accept;
                iifname "lo" accept
                ip saddr ${geproxy} accept
                ip saddr ${contest_subnet} drop
            }

            chain forward {
                type filter hook forward priority filter; policy drop;
            }

            chain output {
                type filter hook output priority filter; policy accept;
                oifname "lo" accept
                ip daddr ${geproxy} tcp dport ${toString cds_port} drop
                ip daddr ${geproxy} accept
                ip daddr ${contest_subnet} drop
            }
        }
      '';
    };
  };

  services.timesyncd = {
    enable = lib.mkForce true;
    servers = [ host ];
  };

  boot.blacklistedKernelModules = [
    "iwlwifi"
    "btusb"
  ];

  # Prevent non-root users from managing network connections via GNOME
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
          subject.user !== "root") {
        return polkit.Result.NO;
      }
    });
  '';
}
