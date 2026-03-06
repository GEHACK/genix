{ config, ... }:
{
  sops.secrets.loom-auth = { };
  services.loomd = {
    enable = true;
    server = "http://192.168.122.1:8080";
    authTokenCommand = "cat ${config.sops.secrets.loom-auth.path}";
  };
}
