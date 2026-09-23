{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.geproxy) networks;

  switchable = lib.attrNames (lib.filterAttrs (_: net: net.internet == "switchable") networks);

  toggle =
    name: state: rule:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.nftables ];
      text = ''
        network=''${1:-${config.geproxy.internetToggle.default}}
        case "$network" in
          ${lib.concatStringsSep "|" switchable}) ;;
          *)
            echo "usage: ${name} [${lib.concatStringsSep "|" switchable}]" >&2
            exit 1
            ;;
        esac
        nft flush chain inet filter "''${network}_inet"
        ${rule}
        echo "$network internet ${state}"
      '';
    };

  hostMaskByPrefix = [
    255
    127
    63
    31
    15
    7
    3
    1
    0
  ];

  broadcast =
    subnet:
    let
      prefix = lib.toInt (lib.last (lib.splitString "/" subnet));
      octets = map lib.toInt (lib.splitString "." (lib.head (lib.splitString "/" subnet)));
      octet =
        i:
        lib.bitOr (lib.elemAt octets i) (
          lib.elemAt hostMaskByPrefix (lib.min 8 (lib.max 0 (prefix - 8 * i)))
        );
    in
    lib.concatMapStringsSep "." (i: toString (octet i)) (lib.range 0 3);
in
{
  options.geproxy.internetToggle.default = lib.mkOption {
    type = lib.types.enum switchable;
    default = lib.head switchable;
    defaultText = lib.literalMD "the first network with `internet = \"switchable\"`";
    description = "Network `enable-internet` and `disable-internet` act on when called without argument.";
  };

  config.environment.systemPackages =
    lib.optionals (switchable != [ ]) [
      (toggle "enable-internet" "ENABLED" ''nft add rule inet filter "''${network}_inet" counter accept'')
      (toggle "disable-internet" "DISABLED" "")
    ]
    ++ [
      (pkgs.writeShellApplication {
        name = "wol";
        runtimeInputs = [ pkgs.wakeonlan ];
        text = ''
          count=0
          ${lib.concatStrings (
            lib.mapAttrsToList (name: net: ''
              while read -r _ mac _; do
                wakeonlan "$mac" -i ${broadcast net.subnet} > /dev/null
                count=$((count + 1))
              done < /var/lib/dnsmasq-${name}/dnsmasq.leases
            '') networks
          )}
          echo "Done. Sent $count WOL packet(s)."
        '';
      })
    ];
}
