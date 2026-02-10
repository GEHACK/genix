{ pkgs, lib, ... }:

let
  judge = "https://judge";
  domjudge-submit = pkgs.python3Packages.buildPythonApplication {
    pname = "domjudge-submit";
    version = "git";
    format = "other";

    src = pkgs.fetchFromGitHub {
      owner = "domjudge";
      repo = "domjudge";
      rev = "main"; 
      sha256 = "sha256-rLYfSmDrQBbaDkTdex/tD+OuaY5Ehqj+7+paiFHTT7o="; 
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
  environment = {
    systemPackages = [
      domjudge-submit
    ];
    sessionVariables = {
      SUBMITBASEURL = judge;
    };
  };
}