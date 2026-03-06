_: {
  sops = {
    age.keyFile = "/etc/sops/hostkey";
    defaultSopsFile = ../secrets.yaml;
    defaultSopsFormat = "yaml";
  };
}
