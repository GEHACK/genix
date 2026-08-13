{ pkgs, ... }:
let
  bridgeAddress = "10.0.0.1";

  netbootxyzBios = pkgs.fetchurl {
    url = "https://github.com/netbootxyz/netboot.xyz/releases/download/${pkgs.netbootxyz-efi.version}/netboot.xyz.kpxe";
    hash = "sha256-eAhpX9u2crNhQXsj3zAYKtYXHUxKAUf0ycqq83FQ3gE=";
  };

  bootMenu = pkgs.writeText "menu.ipxe" ''
    #!ipxe

    menu geminecraft network boot
    item imaged      imaged deployment
    item netbootxyz  netboot.xyz
    item local       boot from local disk
    choose --default imaged --timeout 10000 target && goto ''${target}

    :imaged
    chain http://${bridgeAddress}:8080/boot/boot.ipxe || goto failed

    :netbootxyz
    iseq ''${platform} efi && chain tftp://${bridgeAddress}/netboot.xyz.efi || chain tftp://${bridgeAddress}/netboot.xyz.kpxe
    goto failed

    :local
    exit

    :failed
    prompt Network boot failed. Press any key to reboot.
    reboot
  '';

  tftpRoot = pkgs.runCommand "geminecraft-tftp-root" { } ''
    mkdir -p $out
    cp -r ${pkgs.ipxe}/. $out/
    chmod -R u+w $out
    cp ${pkgs.netbootxyz-efi} $out/netboot.xyz.efi
    cp ${netbootxyzBios} $out/netboot.xyz.kpxe
    cp ${bootMenu} $out/menu.ipxe
  '';
in
{
  services.dnsmasq.settings = {
    enable-tftp = true;
    tftp-root = "${tftpRoot}";

    dhcp-userclass = "set:ipxe,iPXE";
    dhcp-match = [
      "set:bios,60,PXEClient:Arch:00000"
      "set:efi32,60,PXEClient:Arch:00006"
      "set:efibc,60,PXEClient:Arch:00007"
      "set:efi64,60,PXEClient:Arch:00009"
    ];
    dhcp-boot = [
      "tag:!ipxe,tag:bios,undionly.kpxe,,${bridgeAddress}"
      "tag:!ipxe,tag:efi32,ipxe.efi,,${bridgeAddress}"
      "tag:!ipxe,tag:efibc,ipxe.efi,,${bridgeAddress}"
      "tag:!ipxe,tag:efi64,ipxe.efi,,${bridgeAddress}"
      "tag:ipxe,menu.ipxe,,${bridgeAddress}"
    ];
  };
}
