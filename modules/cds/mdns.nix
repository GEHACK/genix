_: {
  services.avahi = {
    enable = true;
    ipv6 = false;
    publish = {
      enable = true;
      addresses = true;
    };
  };
}
