{ stdenv, lib, fetchurl, unzip, makeWrapper, jre }:

stdenv.mkDerivation rec {
  pname = "icpc-presentation";
  version = "2.7.1352";

  src = fetchurl {
    url = "https://github.com/icpctools/icpctools/releases/download/v2.7.1352/resolver-2.7.1352.zip";
    sha256 = "sha256-XfkcJQUwNLSVNv8EKqHDTl6ssY+HKyAvgiSqK0qYH88=";
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