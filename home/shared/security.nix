{config, ...}: {
  # Home-manager-side sops (flat; P9d).
  # Was home/shared/security/default.nix + modules/shared/security/encryption/age-sops.nix,
  # joined by a cross-tree import. Content consolidated here; no upward imports.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      # age key auto-imported from ~/.config/sops/age/keys.txt.
      # Generate: `age-keygen -o ~/.config/sops/age/keys.txt`
      # Or convert from ssh: `ssh-to-age < ~/.ssh/id_ed25519.pub`
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    secrets = {
      # GitHub token for Nix (avoids API rate limits).
      "github-token" = {
        key = "github_token";
        path = ".config/nix/github-token";
      };
      # Context7 CLI (ctx7); shells export CONTEXT7_API_KEY from this path.
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
    };
  };
}
