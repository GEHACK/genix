{ config, pkgs, ... }:

{
  services.power-profiles-daemon.enable = true;

  systemd.services.set-performance-profile = {
    description = "Set power profile to performance on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "power-profiles-daemon.service" ];
    path = [ pkgs.power-profiles-daemon ];
    script = ''
      powerprofilesctl set performance
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # In theory, this is not necessary. But it cannot hurt to set the 
  # governor to performance
  powerManagement.cpuFreqGovernor = "performance";
}