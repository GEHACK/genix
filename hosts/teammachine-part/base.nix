_: {
  imports = [ ./common.nix ];

  teammachine = {
    printer.enable = true;
    remoteDesktop.enable = true;
    usbguard.enable = true;
  };
}
