{
  dotfilesLib,
  lib,
  ...
}:
{
  sops = {
    defaultSopsFile = lib.mkDefault dotfilesLib.sopsFile;
    age.keyFile = lib.mkDefault "/var/lib/private/sops/age/keys.txt";
  };
}
