{
  pkgs,
  lib,
  ...
}:
let
  # Two short word lists plus two digits: 36 * 34 * 100 names, all <= 15
  # characters, so they fit Minecraft's 16 character username limit.
  adjectives = [
    "Bouncy"
    "Brave"
    "Cheeky"
    "Chunky"
    "Cosmic"
    "Crispy"
    "Dapper"
    "Dizzy"
    "Fluffy"
    "Frosty"
    "Funky"
    "Fuzzy"
    "Giddy"
    "Glossy"
    "Grumpy"
    "Jolly"
    "Lucky"
    "Mighty"
    "Nifty"
    "Perky"
    "Plucky"
    "Quirky"
    "Rapid"
    "Rowdy"
    "Salty"
    "Sassy"
    "Silly"
    "Sleepy"
    "Sneaky"
    "Snappy"
    "Spicy"
    "Sunny"
    "Swift"
    "Turbo"
    "Wobbly"
    "Zesty"
  ];

  nouns = [
    "Badger"
    "Beaver"
    "Cactus"
    "Creeper"
    "Dolphin"
    "Falcon"
    "Ferret"
    "Gnome"
    "Hamster"
    "Kraken"
    "Lemur"
    "Llama"
    "Mammoth"
    "Meerkat"
    "Muffin"
    "Narwhal"
    "Newt"
    "Ocelot"
    "Octopus"
    "Otter"
    "Panda"
    "Pickaxe"
    "Pigeon"
    "Puffin"
    "Quokka"
    "Raccoon"
    "Sloth"
    "Squid"
    "Toaster"
    "Turnip"
    "Walrus"
    "Wombat"
    "Waffle"
    "Yeti"
  ];

  pyList = words: "[" + lib.concatMapStringsSep ", " (w: ''"${w}"'') words + "]";

  # Picks the player name from the primary NIC's MAC address, so it is unique
  # per machine and stable across reboots and re-images (a cloned /etc/machine-id
  # would not be), then merges a matching PrismLauncher offline account into the
  # account list. Microsoft accounts already in the list are left alone.
  generator = pkgs.writers.writePython3Bin "minecraft-player-name" { flakeIgnore = [ "E501" ]; } ''
    import hashlib
    import json
    import os
    import pathlib
    import sys
    import time
    import uuid

    ADJECTIVES = ${pyList adjectives}
    NOUNS = ${pyList nouns}


    def candidate_macs():
        # Onboard PCI NICs first: a USB dock or a replaced wifi card must not
        # rename the machine. Virtual interfaces have no "device" link at all.
        net = pathlib.Path("/sys/class/net")
        for usb in (False, True):
            for iface in sorted(p.name for p in net.iterdir()):
                device = net / iface / "device"
                if iface == "lo" or not device.exists():
                    continue
                if ("/usb" in str(device.resolve())) != usb:
                    continue
                mac = (net / iface / "address").read_text().strip()
                if mac and mac != "00:00:00:00:00:00":
                    yield mac


    def machine_seed():
        for mac in candidate_macs():
            return mac
        # No NIC at all: fall back to the (image-wide, so not unique) machine id.
        return pathlib.Path("/etc/machine-id").read_text().strip()


    def player_name(seed):
        digest = hashlib.sha256(seed.encode()).digest()
        return "{}{}{:02d}".format(
            ADJECTIVES[digest[0] % len(ADJECTIVES)],
            NOUNS[digest[1] % len(NOUNS)],
            digest[2] % 100,
        )


    def offline_uuid(name):
        # UUIDv3 over MD5("OfflinePlayer:<name>"), the same value PrismLauncher
        # and an offline-mode server derive for this username.
        digest = bytearray(hashlib.md5(f"OfflinePlayer:{name}".encode()).digest())
        digest[6] = (digest[6] & 0x0F) | 0x30
        digest[8] = (digest[8] & 0x3F) | 0x80
        return bytes(digest).hex()


    def offline_account(name):
        return {
            "active": True,
            "profile": {
                "capes": [],
                "id": offline_uuid(name),
                "name": name,
                "skin": {"id": "", "url": "", "variant": ""},
            },
            "type": "Offline",
            "ygg": {
                "extra": {"clientToken": uuid.uuid4().hex, "userName": name},
                "iat": int(time.time()),
                "token": "0",
            },
        }


    def main():
        path = pathlib.Path(sys.argv[1])
        name = player_name(machine_seed())

        accounts = []
        if path.exists():
            try:
                accounts = json.loads(path.read_text()).get("accounts", [])
            except (json.JSONDecodeError, OSError) as err:
                print(f"ignoring unreadable account list: {err}")

        # Keep Microsoft accounts (they own the game and unlock offline play in
        # PrismLauncher), drop stale generated names, then add this boot's name.
        kept = [a for a in accounts if a.get("type") != "Offline"]
        for account in kept:
            account.pop("active", None)
        kept.append(offline_account(name))

        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".json.new")
        tmp.write_text(json.dumps({"accounts": kept, "formatVersion": 3}, indent=4, sort_keys=True))
        os.replace(tmp, path)
        print(f"minecraft player name: {name}")


    main()
  '';
in
{
  systemd.services.minecraft-player-name = {
    description = "Assign this machine a Minecraft player name";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" ];
    unitConfig.ConditionPathIsDirectory = "/home/minecraft";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "minecraft";
      Group = "users";
      UMask = "0077";
      ExecStart = "${lib.getExe generator} /home/minecraft/.local/share/PrismLauncher/accounts.json";
    };
  };
}
