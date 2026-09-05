{
  pkgs,
  lib,
  sopsModule,
}:
let
  password = "hunter2";

  secrets =
    pkgs.runCommand "teammachine-rdp-test-secrets"
      {
        nativeBuildInputs = [
          pkgs.age
          pkgs.sops
        ];
      }
      ''
        mkdir -p $out
        age-keygen -o $out/key.txt
        echo 'password: ${password}' > plain.yaml
        sops --encrypt --age "$(age-keygen -y $out/key.txt)" plain.yaml > $out/secrets.yaml
        chmod 0400 $out/key.txt
      '';

  stubGreeter = pkgs.writers.writePython3Bin "stub-greeter" { flakeIgnore = [ "E501" ]; } ''
      import json
      import os
      import socket
      import struct

      SESSION = [
          "XDG_SESSION_TYPE=wayland",
          "XDG_SESSION_DESKTOP=gnome",
          "DESKTOP_SESSION=gnome",
          "XDG_CURRENT_DESKTOP=GNOME",
      ]


      def main() -> None:
          sock = socket.socket(socket.AF_UNIX)
          sock.connect(os.environ["GREETD_SOCK"])

          request = {"type": "create_session", "username": "team"}
          while True:
              payload = json.dumps(request).encode()
              sock.sendall(struct.pack("=I", len(payload)) + payload)

              length = struct.unpack("=I", sock.recv(4))[0]
              response = json.loads(sock.recv(length))

              if response["type"] == "auth_message":
                  request = {
                      "type": "post_auth_message_response",
                      "response": "${password}",
                  }
              elif response["type"] == "success":
                  if request["type"] == "start_session":
                      return
                  request = {
                      "type": "start_session",
                      "cmd": ["${pkgs.gnome-session}/bin/gnome-session"],
                      "env": SESSION,
                  }
              else:
                  raise SystemExit(f"greetd refused the login: {response}")


      main()
  '';

  teammachine = {
    imports = [
      sopsModule
      ../modules/teammachine/remote-desktop.nix
    ];

    virtualisation = {
      memorySize = 4096;
      cores = 2;
      qemu.options = [ "-vga virtio" ];
    };

    users.users.team = {
      isNormalUser = true;
      inherit password;
      extraGroups = [
        "video"
        "audio"
      ];
    };

    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = false;

    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session.command = lib.getExe stubGreeter;
      };
    };

    security.pam.services.greetd.enableGnomeKeyring = true;

    environment.etc."teammachine-rdp-test-key".source = secrets + "/key.txt";

    sops = {
      age.keyFile = "/etc/teammachine-rdp-test-key";
      defaultSopsFile = secrets + "/secrets.yaml";
    };

    environment.systemPackages = [ pkgs.freerdp ];

    teammachine.remoteDesktop = {
      enable = true;
      user = "team";
    };
  };

  forgottenKeyring = {
    systemd.services.forgotten-keyring = {
      description = "A login keyring nobody has the password of";
      wantedBy = [ "multi-user.target" ];
      before = [ "greetd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "team";
        RuntimeDirectory = "forgotten-keyring";
        Environment = "XDG_RUNTIME_DIR=/run/forgotten-keyring";
      };
      script = ''
        printf forgotten \
          | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon \
              --unlock --components=pkcs11 --daemonize
      '';
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "teammachine-rdp";

  nodes = {
    fresh = teammachine;
    stale.imports = [
      teammachine
      forgottenKeyring
    ];
  };

  testScript = ''
    session = (
      "XDG_RUNTIME_DIR=/run/user/1000 "
      "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
    )

    def check(machine):
      machine.wait_for_unit("greetd.service")
      machine.wait_until_succeeds("pgrep -u team gnome-shell")
      machine.wait_for_unit("graphical-session.target", "team")
      machine.wait_for_unit("teammachine-rdp-keyring.service", "team")
      machine.wait_for_unit("teammachine-rdp-credentials.service", "team")

      status = machine.succeed(f"su team -c '{session}grdctl status --show-credentials'")
      assert "Username: team" in status, status
      assert "Password: ${password}" in status, status
      assert "Unit status: active" in status, status

      machine.wait_for_open_port(3389)
      machine.fail("pgrep -u team -f gcr-prompter")

      machine.succeed(
        "xfreerdp /v:localhost:3389 /u:team /p:${password} "
        "/cert:ignore +auth-only >&2"
      )
      machine.fail(
        "xfreerdp /v:localhost:3389 /u:team /p:wrong /cert:ignore +auth-only >&2"
      )

    with subtest("a fresh machine"):
      fresh.start()
      check(fresh)
      fresh.shutdown()

    with subtest("a machine carrying a keyring nobody has the password of"):
      stale.start()
      stale.wait_for_unit("forgotten-keyring.service")
      stale.succeed("test -s /home/team/.local/share/keyrings/login.keyring")
      check(stale)
  '';
}
