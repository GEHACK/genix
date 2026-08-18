{ stdenv, lib, fetchurl, unzip, makeWrapper, jre }:

stdenv.mkDerivation rec {
  pname = "icpc-presentation";
  version = "2.7.1396";

  src = fetchurl {
    url = "https://github.com/icpctools/icpctools/releases/download/v${version}/resolver-${version}.zip";
    sha256 = "sha256-0xvHFH3QDAa52+I3x4DwYvfmuSaRD9h7K313sqkcSdA=";
  };

  nativeBuildInputs = [ unzip makeWrapper ];
  buildInputs = [ jre ];

  sourceRoot = ".";

  installPhase = ''
    # 1. Install the jars
    mkdir -p $out/share/icpc/lib
    cp -r lib/* $out/share/icpc/lib/

    # 2. Generate the executable
    mkdir -p $out/bin
    cat > $out/bin/presentation-client <<EOF
    #!/bin/sh
    LIB_DIR="$out/share/icpc/lib"
    CACHE_DIR="\''${TMPDIR:-/tmp}/org.icpc.tools.cache"

    exec ${jre}/bin/java -Xmx4096m -cp "\$LIB_DIR/*" \
      org.icpc.tools.presentation.contest.internal.ClientLauncher "\$@"
    EOF

    chmod +x $out/bin/presentation-client
  '';

  meta = with lib; {
    description = "ICPC Presentation Client";
    mainProgram = "presentation-client";
  };
}