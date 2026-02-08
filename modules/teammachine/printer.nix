{ pkgs, ... }: {
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

#hardware.printers = {
#  ensurePrinters = [
#    {
#      name = "Contest_Printer";
#      deviceUri = "ipp://10.1.0.1:631";
#      model = "drv:///sample.drv/ipp-everywhere.ppd";
#      ppdOptions = {
#        PageSize = "A4";
#      };
#    }
#  ];
#  ensureDefaultPrinter = "Contest_Printer";
#};

}