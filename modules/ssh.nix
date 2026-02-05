_: {
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
