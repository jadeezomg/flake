{config, ...}: let
  # Sops *attribute* name for the GitHub PAT file. Must be one of `githubPatSecretAttrs` in
  # `home/shared/shells/sops-session-env.nix` (e.g. "github-token" or "gh-token").
  githubPatSecretAttrName = "github-token";
  githubPatSecret = {
    key = "github_token";
    path = ".config/nix/github-token";
  };
in {
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      # age key auto-imported from ~/.config/sops/age/keys.txt.
      # Generate: `age-keygen -o ~/.config/sops/age/keys.txt`
      # Or convert from ssh: `ssh-to-age < ~/.ssh/id_ed25519.pub`
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    secrets =
      {
        ${githubPatSecretAttrName} = githubPatSecret;
        "agent-pat" = {
          key = "agent_pat";
          path = ".config/nix/agent-pat";
        };
      }
      // {
        "context7-api-key" = {
          key = "context7_api_key";
          path = ".config/context7/api-key";
        };
        "inception-api-key" = {
          key = "inception_api_key";
          path = ".config/nix/inception-api-key";
        };
        "kagi-session-token" = {
          key = "kagi_session_token";
          path = ".kagi_session_token";
        };
        "openrouter-api-key" = {
          key = "openrouter_api_key";
          path = ".config/nix/openrouter-api-key";
        };
        "hf-token" = {
          key = "hf_token";
          path = ".config/nix/hf-token";
        };
      };
  };
}
