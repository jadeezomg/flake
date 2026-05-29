{lib, ...}: {
  sops = {
    defaultSopsFile = lib.mkDefault ../../secrets/secrets.yaml;
    age.keyFile = lib.mkDefault "/var/lib/private/sops/age/keys.txt";
  };
}
