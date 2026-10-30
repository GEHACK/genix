{
  lib,
  runCommand,
  buildEnv,
  closureInfo,
  writeText,
  bash,
  coreutils,
  findutils,
  gnused,
  contestToolchain,
  runUsers,
}:
let
  tools = buildEnv {
    name = "domjudge-chroot-tools";
    paths = lib.attrValues contestToolchain ++ [
      bash
      coreutils
      findutils
      gnused
    ];
    pathsToLink = [ "/bin" ];
  };

  passwd = writeText "passwd" (
    lib.concatLines (
      [
        "root:x:0:0:root:/:/bin/sh"
        "nobody:x:65534:65534:nobody:/nonexistent:/bin/false"
      ]
      ++ lib.mapAttrsToList (
        name: uid: "${name}:x:${toString uid}:65534::/nonexistent:/bin/false"
      ) runUsers
    )
  );

  group = writeText "group" ''
    root:x:0:
    nogroup:x:65534:
  '';
in
runCommand "domjudge-chroot" { closure = closureInfo { rootPaths = [ tools ]; }; } ''
  mkdir -p $out/etc $out/lib $out/lib64 $out/usr/bin $out/nix/store
  xargs cp -a -t $out/nix/store < $closure/store-paths
  cp -a ${tools}/bin/. $out/usr/bin/
  ln -s usr/bin $out/bin
  cp ${passwd} $out/etc/passwd
  cp ${group} $out/etc/group
  touch $out/etc/resolv.conf
''
