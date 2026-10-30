{ config, ... }:
{
  imaged.image.secrets.hostkey = {
    path = config.sops.age.keyFile;
    label = "sops hostkey";
    description = "age key that decrypts secrets.yaml";
    perMachine = false;
  };
}
