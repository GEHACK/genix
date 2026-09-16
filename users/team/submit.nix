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
      rev = "f4457ecb11a8c4dc9254d79709a253d4b4ea78ed";
      sha256 = "sha256-cHZLU9Dk6mdRYDpJ887XQUGgRcoPS18Pp6b+7kFUaFs=";
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
