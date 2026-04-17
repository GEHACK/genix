{ pkgs, ... } : 

{
  networking.firewall.allowedTCPPorts = [ 8080 8081 ];

  systemd.user.services.cds-desktop = {
    description = "CDS Team Desktop Stream (wf-recorder + VLC)";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    # Add wf-recorder and vlc to the path
    path = with pkgs; [ wf-recorder vlc bash ];

    serviceConfig = {
      # 1. wf-recorder grabs the screen and pipes raw video to stdout
      # 2. VLC reads from stdin (fd://0) and broadcasts via HTTP
      ExecStart = pkgs.writeScript "start-gnome-stream" ''
        #!${pkgs.bash}/bin/bash
        ${pkgs.wf-recorder}/bin/wf-recorder -o any -f - | \
        ${pkgs.vlc}/bin/vlc -I dummy \
          fd://0 \
          --demux h264 \
          --sout "#transcode{vcodec=h264,vb=0,scale=0,fps=15}:http{mux=ts,dst=:8081}"
      '';
      
      Restart = "always";
      RestartSec = "5s";
    };
  };
}