{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.teammachine.remoteDesktop;

  stateDir = "/var/lib/teammachine-rdp";
  tlsCert = "${stateDir}/rdp.crt";
  tlsKey = "${stateDir}/rdp.key";

  passwordFile = config.sops.secrets.password.path;

  storeCredentials = pkgs.writeShellScript "teammachine-rdp-credentials" ''
    set -eu
    grdctl() {
      ${lib.getExe' pkgs.coreutils "timeout"} 5 \
        ${lib.getExe' pkgs.gnome-remote-desktop "grdctl"} "$@"
    }

    for _ in $(${lib.getExe' pkgs.coreutils "seq"} 1 30); do
      grdctl rdp set-credentials ${cfg.user} < ${passwordFile} || true
      if grdctl status --show-credentials 2>/dev/null \
        | ${lib.getExe pkgs.gnugrep} -q "Username: ${cfg.user}"; then
        exit 0
      fi
      sleep 1
    done

    echo "teammachine-rdp: could not store the RDP password in the login keyring" >&2
    exit 1
  '';
in
{
  options.teammachine.remoteDesktop = {
    enable = lib.mkEnableOption "remote control of the live contest session over RDP";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.services.greetd.loom-greeter.username;
      defaultText = lib.literalExpression "config.services.greetd.loom-greeter.username";
      description = ''
        User whose live session is served over RDP. Defaults to the user the
        greeter logs in, and doubles as the RDP username remote clients
        authenticate with.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "TCP port the RDP server listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.password.mode = "0444";

    services.gnome.gnome-keyring.enable = true;
    services.gnome.gnome-remote-desktop.enable = true;

    services.desktopManager.gnome = {
      extraGSettingsOverridePackages = [ pkgs.gnome-remote-desktop ];
      extraGSettingsOverrides = ''
        [org.gnome.desktop.remote-desktop.rdp]
        enable=true
        port=${toString cfg.port}
        negotiate-port=false
        view-only=false
        tls-cert='${tlsCert}'
        tls-key='${tlsKey}'
        screen-share-mode='mirror-primary'
      '';
    };

    systemd.services.teammachine-rdp-tls = {
      description = "Certificate for contest session remote access";
      wantedBy = [ "multi-user.target" ];
      before = [ "greetd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = baseNameOf stateDir;
        StateDirectoryMode = "0755";
      };
      script = ''
        if [ ! -s ${tlsCert} ] || [ ! -s ${tlsKey} ]; then
          ${lib.getExe pkgs.openssl} req -x509 -newkey rsa:4096 -nodes -days 3650 \
            -subj "/CN=${config.networking.hostName}" \
            -keyout ${tlsKey} -out ${tlsCert}
        fi
        chown ${cfg.user} ${tlsCert} ${tlsKey}
        chmod 0644 ${tlsCert}
        chmod 0600 ${tlsKey}
      '';
    };

    systemd.user.services = {
      gnome-remote-desktop = {
        overrideStrategy = "asDropin";
        wantedBy = [ "gnome-session.target" ];
      };

      teammachine-rdp-keyring-reset = {
        description = "Discard a login keyring earlier contest sessions left behind";
        partOf = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        before = [ "teammachine-rdp-keyring.service" ];
        unitConfig.ConditionUser = cfg.user;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe' pkgs.coreutils "rm"} -rf %h/.local/share/keyrings";
        };
      };

      teammachine-rdp-keyring = {
        description = "Login keyring holding the contest session RDP credentials";
        partOf = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        after = [
          "graphical-session.target"
          "teammachine-rdp-keyring-reset.service"
        ];
        before = [ "teammachine-rdp-credentials.service" ];
        unitConfig.ConditionUser = cfg.user;
        serviceConfig = {
          ExecStart = "/run/wrappers/bin/gnome-keyring-daemon --replace --unlock --foreground";
          StandardInput = "file:${passwordFile}";
          Restart = "always";
          RestartSec = 2;
        };
      };

      teammachine-rdp-credentials = {
        description = "Credentials for contest session remote access";
        partOf = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        after = [
          "graphical-session.target"
          "teammachine-rdp-keyring.service"
        ];
        requires = [ "teammachine-rdp-keyring.service" ];
        before = [ "gnome-remote-desktop.service" ];
        unitConfig.ConditionUser = cfg.user;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 120;
          ExecStart = "${storeCredentials}";
        };
      };
    };
  };
}
