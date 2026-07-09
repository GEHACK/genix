{
  config,
  pkgs,
  lib,
  dj_url,
  ...
}:
let
  domjudge-submit = pkgs.python3Packages.buildPythonApplication {
    pname = "domjudge-submit";
    version = "git";
    format = "other";

    src = pkgs.fetchFromGitHub {
      owner = "domjudge";
      repo = "domjudge";
      rev = "d8c018e4c6ec050b0089f178976ba1129307beb3";
      sha256 = "sha256-I1MtfpnWwSZuVW1STeIDZacX8BUToUTVhckQRtrPoXs=";
    };

    propagatedBuildInputs = with pkgs.python3Packages; [
      requests
      python-magic
    ];

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      install -Dm755 submit/submit $out/bin/submit
    '';

    meta = with lib; {
      mainProgram = "submit";
    };
  };
in
{
  options.teammachine.submit.enable = lib.mkEnableOption "DOMjudge submit CLI";

  config = lib.mkIf config.teammachine.submit.enable {
    home.packages = [ domjudge-submit ];
    home.sessionVariables.SUBMITBASEURL = dj_url;
  };
}
