{ pkgs, ...}: 
let 
  # 1. We define the theme name and the image path
  themeName = "euc2027-splash";
  # Ensure this path is correct relative to your configuration file!
  imagePath = ../../assets/boot.png; 
  
  euc2027-theme = pkgs.stdenv.mkDerivation {
    pname = "${themeName}";
    version = "1.0";
    src = null;

    # We copy the image and generate the config files
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/plymouth/themes/${themeName}
      
      cp ${imagePath} $out/share/plymouth/themes/${themeName}/background.png

      cat > $out/share/plymouth/themes/${themeName}/${themeName}.plymouth <<EOF
      [Plymouth Theme]
      Name=${themeName}
      Description=My Custom Wallpaper Theme
      ModuleName=script
      
      [script]
      ImageDir=$out/share/plymouth/themes/${themeName}
      ScriptFile=$out/share/plymouth/themes/${themeName}/${themeName}.script
      EOF

      cat > $out/share/plymouth/themes/${themeName}/${themeName}.script <<EOF
      
      bg_image = Image("background.png");
      
      screen_width = Window.GetWidth();
      screen_height = Window.GetHeight();
      resized_bg_image = bg_image.Scale(screen_width, screen_height);
      
      bg_sprite = Sprite(resized_bg_image);
      bg_sprite.SetZ(-100); # Put it continuously in the background
      EOF
    '';
  };
in
{
  boot = {
    # 1. The Console & Kernel Silence
    consoleLogLevel = 0;
    initrd = {
      verbose = false; # Silence the initial ramdisk
      kernelModules = [ "i915" ];
    };

    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    plymouth = {
      enable = true;
      themePackages = [ euc2027-theme ];
      theme = "euc2027-splash";
    };
    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        efiSupport = true;
        zfsSupport = true;
        efiInstallAsRemovable = true;
        timeoutStyle = "hidden"; #If this option is set to ‘countdown’ or ‘hidden’ […] and ESC or F4 are pressed, or SHIFT is held down during that time, it will display the menu and wait for input.
        devices = [ "nodev" ];
        backgroundColor = "#034638";
        splashImage = ../../assets/boot.png;
      };
    };
  };
}