{ lib, config, ... }:
{
  options.geproxy.loomDns.enable = lib.mkEnableOption "resolving `team.loom` through loom's DNS-over-HTTPS endpoint";

  config = lib.mkIf config.geproxy.loomDns.enable {
    services.https-dns-proxy = {
      enable = true;
      address = "127.0.0.1";
      port = 5053;
      extraArgs = [
        "-r"
        "https://loom.gehack.nl/api/dns-query"
        "-b"
        "127.0.0.53"
      ];
    };

    geproxy.dns.forward."team.loom" = "127.0.0.1#5053";
  };
}
