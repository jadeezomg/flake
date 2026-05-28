{lib, ...}: {
  sops = {
    defaultSopsFile = lib.mkDefault ../../secrets/secrets.yaml;
    age.sshKeyPaths = lib.mkDefault ["/etc/ssh/ssh_host_ed25519_key"];
  };
}
