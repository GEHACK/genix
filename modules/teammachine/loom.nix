{ config, ... }:
{
  sops.secrets.loom-auth = { };
  services.loomd = {
    enable = true;
    server = "https://loom.gehack.nl";
    authTokenCommand = "cat ${config.sops.secrets.loom-auth.path}";
  };
}
