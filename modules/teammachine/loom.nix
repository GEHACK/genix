{ config, loom_url, ... }:
{
  sops.secrets."loom.authToken" = { };
  services.loomd = {
    enable = true;
    server = loom_url;
    authTokenCommand = "cat ${config.sops.secrets."loom.authToken".path}";
    includeSystemPackages = true;
  };
}
