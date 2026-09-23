{ lib, config, ... }:
{
  options.geproxy.ntp.enable = lib.mkEnableOption "serving NTP to the networks that allow `ntp`";

  config = lib.mkIf config.geproxy.ntp.enable {
    services.timesyncd.enable = false;
    services.chrony = {
      enable = true;
      extraConfig = ''
        allow
        makestep 1.0 -1
      '';
    };

    geproxy.ports.ntp.udp = [ 123 ];
  };
}
