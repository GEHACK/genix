_: {
  services.cuproxy = {
    enable = true;
    logLevel = "trace";
    printerTo = "10.0.0.10:631/ipp/print";
  };
}
