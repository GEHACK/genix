{ config, dj_url, ... }:
let
  greeter-user = config.services.greetd.settings.default_session.user;
in
{
  sops.secrets.greeter-chain.owner = greeter-user;
  sops.secrets.password.owner = greeter-user;
  services.greetd.loom-greeter = {
    enable = true;
    logLevel = "debug";
    backgroundSource = ../../assets/wallpaper.jpeg;
    url = dj_url;
    username = "team";
    password.command = "cat ${config.sops.secrets.password.path}";
    chain.command = "cat ${config.sops.secrets.greeter-chain.path}";
  };

}
