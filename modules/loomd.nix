{
  lib,
  config,
  loom_url,
  ...
}:
{
  config = lib.mkIf (config.services.loomd.label != null) {
    sops.secrets."loom.authToken" = { };

    services.loomd = {
      enable = true;
      server = loom_url;
      authTokenCommand = "cat ${config.sops.secrets."loom.authToken".path}";
      includeSystemPackages = true;
      greeter.enable = config.services.greetd.enable;
      enableRegistrationTool = config.services.greetd.enable;
    };
  };
}
