{
  config,
  lib,
  ...
}: {
  # SOPS-Nix secret management (home-manager only). age/sops are on the system via encryption/tools.nix.
  sops = lib.mkIf (builtins.hasAttr "home" config) {
    defaultSopsFile = ../../../../secrets/secrets.yaml;

    # Age key configuration
    # The age key will be automatically imported from ~/.config/sops/age/keys.txt
    # or from /var/lib/sops-nix/key.txt on NixOS
    age = {
      # Generate SSH key for age: ssh-keygen -t ed25519 -C "sops-nix"
      # Convert to age key: ssh-to-age < ~/.ssh/id_ed25519.pub
      # Or generate age key directly: age-keygen

      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };

    # Secrets to decrypt and make available
    secrets = {
      # GitHub token for Nix (avoids API rate limits). Place at ~/.config/nix/github-token.
      "github-token" = {
        key = "github_token";
        path = ".config/nix/github-token";
      };

      # Context7 CLI (ctx7); shells export CONTEXT7_API_KEY from this path
      "context7-api-key" = {
        key = "context7_api_key";
        path = ".config/context7/api-key";
      };

      "inception-api-key" = {
        key = "inception_api_key";
        path = ".config/nix/inception-api-key";
      };

      "kagi-api-key" = {
        key = "kagi_api_key";
        path = ".config/nix/kagi-api-key";
      };

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
