{
  lib,
  dockerTools,
  python3Minimal,
}:
# Write-only receiver for runtimes ISO reports, run with compose.yaml behind the
# Cloudflare Tunnel that serves runtimes.gehack.nl. Nothing but a minimal python and
# receiver.py: no shell, so `docker exec` can only run what the image ships.
dockerTools.buildLayeredImage {
  name = "ghcr.io/gehack/runtimes-receiver";
  contents = [ python3Minimal ];

  extraCommands = ''
    mkdir -p app data
    cp ${./receiver.py} app/receiver.py
  '';
  fakeRootCommands = ''
    chown 65534:65534 data
    chmod 0700 data
  '';

  config = {
    User = "65534:65534";
    Entrypoint = [
      (lib.getExe python3Minimal)
      "/app/receiver.py"
    ];
    # Rotating the upload token means a new hash here and a new image, or overriding
    # the third argument in the deployment.
    Cmd = [
      "0.0.0.0:8095"
      "/data"
      (lib.fileContents ../runtimes-iso/assets/upload_token.sha256)
    ];
    Env = [ "PYTHONUNBUFFERED=1" ];
    ExposedPorts."8095/tcp" = { };
    Volumes."/data" = { };
  };
}
