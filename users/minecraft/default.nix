{
  config,
  lib,
  pkgs,
  ...
}:
let
  # PrismLauncher's own defaults pull in a language wizard, a Java wizard and a
  # theme wizard on first start. Everything below is what those wizards would
  # write, pinned to English, so the only thing left on first launch is the
  # Microsoft account page (an account is mandatory: PrismLauncher refuses to
  # add an offline account until one MSA account that owns Minecraft exists).
  # Java needs no wizard either, the launcher wrapper hands it jdk25/21/17/8
  # through PRISMLAUNCHER_JAVA_PATHS and picks per instance.
  defaultConfig = pkgs.writeText "prismlauncher.cfg" ''
    [General]
    ApplicationTheme=system
    AutomaticJavaDownload=false
    AutomaticJavaSwitch=true
    ConfigVersion=1.3
    IconTheme=pe_colored
    IgnoreJavaWizard=true
    Language=en_US
    PastebinURL=
    UseSystemLocale=false
    UserAskedAboutAutomaticJavaDownload=true
  '';

  configPath = "${config.xdg.dataHome}/PrismLauncher/prismlauncher.cfg";
in
{
  # Downtime gaming account: Minecraft and nothing else, on a stock GNOME
  # session. It deliberately does not import ../common (Firefox, Neovim) or any
  # of the contest tooling that lives in ../team.
  home = {
    stateVersion = "25.11";
    packages = [ pkgs.prismlauncher ];

    # PrismLauncher rewrites this file whenever a setting changes, so it cannot
    # be a home-manager symlink into the store. Seed it once and leave it alone
    # afterwards, so a player's own settings survive.
    activation.prismlauncherDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e ${lib.escapeShellArg configPath} ]; then
        run mkdir -p ${lib.escapeShellArg (builtins.dirOf configPath)}
        run install -m 600 ${defaultConfig} ${lib.escapeShellArg configPath}
      fi
    '';
  };

  programs.home-manager.enable = true;
}
