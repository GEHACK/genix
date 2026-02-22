{ pkgs, ... }: {
  # This is a list of random packages we decided to include based on the NAC26 image
  environment.systemPackages = with pkgs; [
    wget 
    tmux
    zip
    unzip
    p7zip
  ];
}