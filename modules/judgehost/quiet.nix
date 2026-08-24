{ lib, ... }:
{
  # Anything that spontaneously uses CPU or disk perturbs measured run times.
  # domjudge-scripts masks the apt and tmpfiles timers for this reason; on NixOS
  # the equivalent background work is store GC, store optimisation and fstrim.
  nix = {
    gc.automatic = lib.mkForce false;
    settings.auto-optimise-store = lib.mkForce false;
  };

  services = {
    fstrim.enable = false;
    logrotate.enable = false;
    logind.settings.Login.HandlePowerKey = "ignore";
  };

  systemd = {
    suppressedSystemUnits = [ "systemd-tmpfiles-clean.timer" ];

    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
