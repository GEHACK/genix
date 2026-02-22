{ pkgs, ... }: {
  # This is a list of random packages we decided to include based on the NAC26 image
  environment.systemPackages = with pkgs; [
    # Debugging and profiling
    valgrind 
    strace
    shellcheck

    # Multiplexer
    tmux
    screen

    # CLI downloading
    wget 

    # Zipping and unzipping 
    zip
    unzip
    p7zip

    # Monitoring 
    btop
    htop
    iotop
    sysstat
  ];
}