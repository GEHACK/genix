_:
{
  teammachine = {
    users.team = {
      languages = {
        c.enable = true;
        cpp.enable = true;
        python.enable = true;
        java.enable = true;
        kotlin.enable = true;
      };
      neovim.enable = true;
      firefox.enable = true;
      ides.enable = true;
      ides.jetbrains.enable = true;
      submit.enable = true;
      games.enable = true;
      misc-packages.enable = true;
      trackpad.enable = true;

      streams = {
        enable = false;
        encoder = "vah264enc rate-control=vbr key-int-max=12 ! h264parse";
        webcam = "/dev/video0";
      };
    };
    printer.enable = true;
    remoteDesktop.enable = true;

    users.gehack = {
      neovim.enable = true;
      firefox.enable = true;
      trackpad.enable = true;
    };
    usbguard.enable = true;
  };

  nixpkgs.config.allowUnfree = true;
}
