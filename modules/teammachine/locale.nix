{ pkgs, ... } :
{

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";  

  environment.systemPackages = with pkgs; [
    hunspellDicts.nl_NL
    hunspellDicts.en_US
    hunspellDicts.de_DE
    hunspellDicts.fr-moderne
  ];
}