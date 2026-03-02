{ pkgs, ... } : {
  networking.firewall.allowedTCPPorts = [ 8080 ];

  systemd.services.webcam-stream = {
    description = "Team Webcam Stream (VLC)";
    # wantedBy = [ "multi-user.target" ]; #Uncomment to start on boot
    after = [ "network.target" ];

    serviceConfig = {
      RuntimeDirectory = "webcam-stream";
      Environment = "HOME=/run/webcam-stream";

      ExecStart = ''
        ${pkgs.vlc}/bin/vlc -I dummy -q v4l2:///dev/video0:chroma=mjpg:width=640:height=480:aspect-ratio="16:9" \
        :input-slave=alsa://plughw:0,0 \
        --sout "#transcode{vcodec=h264,vb=0,scale=0,fps=15,acodec=mpga,ab=128,channels=2}:http{mux=ts,dst=:8080}"
      '';

      Restart = "always";
      RestartSec = "5s";
      
      DynamicUser = true;
      SupplementaryGroups = [ "video" "audio" ];
      PrivateDevices = false; 
    };
  };

  
}