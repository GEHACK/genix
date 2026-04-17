{ config, loom_url, ... }:
{
  sops.secrets.loom-auth = { };
  services.loomd = {
    enable = true;
    server = loom_url;
    authTokenCommand = "cat ${config.sops.secrets.loom-auth.path}";
  };
}
