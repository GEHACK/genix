_: {
  services.cuproxy = {
    enable = true;

    # Required: the real printer to forward jobs to.
    printerTo = "printserver.lan:631/printers/MyPrinter";

    # Optional: override defaults.
    listen = ":631";
    logLevel = "info";
    useGhostscript = false;

    # Any env var not covered by a structured option goes here.
    extraEnv = {
      BANNER_APPEND = "false";
      PDF_PAGE_SIZE = "A4";
      PDF_LANDSCAPE = "false";
      PDF_FONT_SIZE = "12";
      PDF_LEFT_MARGIN = "10";
      PDF_TOP_MARGIN = "10";
    };

    # Optional: keep secrets (e.g. WEBHOOK_REQUEST_NONCE) out of the Nix store.
    # environmentFile = "/run/secrets/cuproxy.env";
  };
}
