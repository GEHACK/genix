{
  config,
  lib,
  pkgs,
  cds_port,
  ...
}:
let
  cfg = config.utility;
  secrets = config.sops.secrets;

  scoreboard = pkgs.writeShellScriptBin "scoreboard" ''
    USERNAME=$(cat ${secrets."cds.presentation-client.username".path})
    PASSWORD=$(cat ${secrets."cds.presentation-client.password".path})

    exec ${lib.getExe pkgs.icpc-presentation} "${cfg.presentation.cdsUrl}/api/contests/${cfg.presentation.contestId}" "$USERNAME" "$PASSWORD"
  '';

  # Chromium ignores --kiosk under ozone-wayland; --app is what drops the tab
  # strip and omnibox. The profile lives in the runtime dir, so every login
  # starts clean with no crash-restore prompts.
  balloons = pkgs.writeShellScriptBin "balloons" ''
    exec ${lib.getExe pkgs.chromium} \
      --app="${cfg.balloons.url}" \
      --start-fullscreen \
      --ozone-platform=wayland \
      --user-data-dir="$XDG_RUNTIME_DIR/balloons-chromium" \
      --no-first-run \
      --no-default-browser-check \
      --disable-session-crashed-bubble \
      --disable-features=Translate \
      --password-store=basic
  '';

  presentation-launcher = pkgs.makeDesktopItem {
    name = "gehack-presentation";
    desktopName = "Scoreboard Presentation";
    comment = "ICPC presentation client connected to the CDS";
    exec = lib.getExe scoreboard;
    icon = "video-display";
    categories = [ "Utility" ];
  };

  balloons-launcher = pkgs.makeDesktopItem {
    name = "gehack-balloons";
    desktopName = "Balloons";
    comment = "Balloon runner dashboard";
    exec = lib.getExe balloons;
    icon = "emblem-favorite";
    categories = [ "Utility" ];
  };
in
{
  options.utility = {
    presentation = {
      cdsUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://cds.gehack.nl:${toString cds_port}";
        description = "Base URL of the Contest Data Server, without trailing slash.";
      };

      contestId = lib.mkOption {
        type = lib.types.str;
        default = "__CONTEST__";
        description = ''
          CDS contest id the presentation client connects to. The default is a
          placeholder that geproxy's contest-placeholder middleware rewrites to the
          contest id declared in flake.nix, so the machine never needs a rebuild
          between contests.

          The middleware is a replacePathRegex, so the placeholder is substituted
          in the request path only. A query string reaches DOMjudge verbatim.
        '';
      };
    };

    balloons.url = lib.mkOption {
      type = lib.types.str;
      default = "https://balloons.gehack.nl";
      description = "Page the Balloons launcher opens full screen.";
    };
  };

  config = {
    sops.secrets = {
      "cds.presentation-client.username".owner = "gehack";
      "cds.presentation-client.password".owner = "gehack";
    };

    # On PATH too, so both start from a terminal as `scoreboard` / `balloons`.
    environment.systemPackages = [
      scoreboard
      balloons
      presentation-launcher
      balloons-launcher
    ];

    # GNOME has no desktop icons, so the launchers are pinned to the dash.
    programs.dconf.profiles.user.databases = [
      {
        settings."org/gnome/shell".favorite-apps = [
          "gehack-presentation.desktop"
          "gehack-balloons.desktop"
          "firefox.desktop"
          "org.gnome.Terminal.desktop"
          "org.gnome.Nautilus.desktop"
        ];
      }
    ];
  };
}
