{ judge_ip, ... }:
{
  # DOMjudge registers each daemon as "<hostname>-<DAEMON_ID>", so every machine needs
  # its own name. dnsmasq supplies it from the dhcp-host reservations on geproxy.
  networking.hostName = "";

  services.timesyncd.servers = [ judge_ip ];
}
