{
  pkgs,
  judge_ip,
  contest_subnet,
  ...
}:
{

  environment.systemPackages = with pkgs; [
    wakeonlan
  ];

  networking = {
    hostName = "team";
    useDHCP = false;
    extraHosts = ''
      ${judge_ip} judge
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
            chain input {
                type filter hook input priority filter; policy accept;
                iifname "lo" accept
                ct state established,related accept
                ip saddr ${judge_ip} accept
                # Minecraft: accept sessions other contest machines open to a
                # server hosted here (vanilla /publish 25565 or a dedicated server).
                tcp dport 25565 accept
                udp dport 25565 accept
                ip saddr ${contest_subnet} drop
            }

            chain forward {
                type filter hook forward priority filter; policy drop;
            }

            chain output {
                type filter hook output priority filter; policy accept;
                oifname "lo" accept
                ip daddr ${judge_ip} accept
                # Replies on sessions the input chain already accepted, so a
                # Minecraft server hosted here can answer contest-subnet clients.
                ct state established,related accept
                # Minecraft: reach servers hosted on other contest machines.
                tcp dport 25565 accept
                udp dport 25565 accept
                ip daddr ${contest_subnet} drop
            }
        }
      '';
    };
  };

  services.timesyncd = {
    enable = true;
    servers = [ "10.0.0.1" ];
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
