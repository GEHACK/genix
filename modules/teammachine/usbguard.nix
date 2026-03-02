_ : {
  services.usbguard = {
    enable = true;
    presentDevicePolicy = "allow"; 
    ## Additional configuration is required here 
    ## For now presentDevicePolicy is done but at the contest we need to be more strict
  };
}