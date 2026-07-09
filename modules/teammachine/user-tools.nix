{
  config,
  lib,
  ...
}:
{
  # Router that lets the whole image be configured from a single teammachine.*
  # block in the host file. System services are plain teammachine.* options
  # (printer, usbguard, ...); per-user home-manager tools go under
  # teammachine.users.<name> and are forwarded verbatim to
  # home-manager.users.<name>.teammachine (where users/common + users/team
  # define and consume them).
  options.teammachine.users = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    example = {
      team = {
        neovim.enable = true;
        languages.cpp.enable = true;
      };
    };
    description = "Per-user teammachine tool toggles, keyed by username.";
  };

  config.home-manager.users = lib.mapAttrs (_name: userCfg: {
    teammachine = userCfg;
  }) config.teammachine.users;
}
