{ lib, pkgs, ... }:
{
  # tty1 is the only thing anyone looks at on a judgehost, so it shows btop instead
  # of a login prompt. A dedicated unit rather than getty autologin: there is no
  # shell behind it to fall back into, and no session that survives quitting btop.
  # Alt+F2..F6 still reach a normal getty.
  users = {
    groups.monitor = { };
    users.monitor = {
      isSystemUser = true;
      group = "monitor";
      description = "tty1 system monitor";
    };
  };

  systemd.services = {
    "getty@tty1".enable = false;

    judgehost-btop = {
      description = "btop on tty1";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-user-sessions.service" ];
      conflicts = [ "getty@tty1.service" ];

      environment = {
        TERM = "linux";
        XDG_CONFIG_HOME = "/var/lib/judgehost-btop";
      };

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.btop} --update 2000";
        User = "monitor";
        Group = "monitor";
        StateDirectory = "judgehost-btop";
        WorkingDirectory = "/var/lib/judgehost-btop";

        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal";

        Restart = "always";
        RestartSec = "2s";

        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };
  };

  environment.systemPackages = [ pkgs.btop ];
}
