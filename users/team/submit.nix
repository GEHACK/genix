{
  config,
  pkgs,
  lib,
  team_dj_url,
  ...
}:
{
  options.teammachine.submit.enable = lib.mkEnableOption "DOMjudge submit CLI";

  config = lib.mkIf config.teammachine.submit.enable {
    home.packages = [ (pkgs.domjudge-submit.override { submitBaseUrl = team_dj_url; }) ];
  };
}
