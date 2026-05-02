_: {
  services.timesyncd.enable = false;
  services.chrony = {
    enable = true;
    extraConfig = ''
      allow
      makestep 1.0 -1
    '';
  };
}
