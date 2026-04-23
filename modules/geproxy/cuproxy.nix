_: {
  services.cuproxy = {
    enable = true;
    logLevel = "trace";
    printerTo = "10.0.0.10:631/ipp/print";
    settings = {
      WEBHOOKS_TO_CALL = "info;GET;https://loom.gehack.nl/team-info/10.0.0.92|logo;GET;https://euc-static.gehack.nl/logos/black.png";
      TYPST_TEMPLATE = ./assets/print_template.typ;
    };
  };
}
