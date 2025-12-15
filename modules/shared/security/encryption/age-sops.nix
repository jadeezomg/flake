{
  config,
  lib,
  ...
}: {
  # SOPS-Nix configuration for secret management
  # Only apply in home-manager context, not NixOS system context
  sops = lib.mkIf (builtins.hasAttr "home" config) {
    # Default secrets location
    defaultSopsFile = ./secrets/secrets.enc.yaml;

    # Age key configuration
    # The age key will be automatically imported from ~/.config/sops/age/keys.txt
    # or from /var/lib/sops-nix/key.txt on NixOS
    age = {
      # Generate SSH key for age: ssh-keygen -t ed25519 -C "sops-nix"
      # Convert to age key: ssh-to-age < ~/.ssh/id_ed25519.pub
      # Or generate age key directly: age-keygen

      # For home-manager, sops-nix will look for ~/.config/sops/age/keys.txt
      # For NixOS/Darwin systems, it will look for /var/lib/sops-nix/key.txt

      # You can specify key files explicitly:
      # keyFile = "/home/user/.config/sops/age/keys.txt"; # for home-manager
      # keyFile = "/var/lib/sops-nix/key.txt"; # for NixOS/Darwin systems

      # Generate keys for each host and add public keys to .sops.yaml
      generateKey = false; # Set to true if you want sops-nix to generate keys
    };

    # Secrets to decrypt and make available
    secrets = {
      # Example: decrypt a secret and make it available as /run/secrets/my-secret
      # my-secret = { };

      # Example: decrypt and set as environment variable
      # my-env-var = {
      #   sopsFile = ./secrets/env-vars.yaml;
      # };

      # Example: decrypt for a specific user
      # user-secret = {
      #   owner = "jadee";
      #   group = "users";
      #   mode = "0400";
      # };
    };
  };
}
