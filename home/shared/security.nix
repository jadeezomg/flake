{config, ...}: {
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
      "github-token" = {
        key = "github_token";
        path = ".config/nix/github-token";
      };
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
