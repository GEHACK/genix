{ pkgs, ... }: {
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

hardware.printers = {
 ensurePrinters = [
   {
     name = "PSGEWIS1";
     deviceUri = "ipp://10.0.0.1:631/ipp/print";
     model = "everywhere";
     # ppdOptions = {
     #   PageSize = "A4";
     # };
   }
 ];
 ensureDefaultPrinter = "PSGEWIS1";
};

}
