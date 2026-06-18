{
  dotfilesLib,
  config,
  ...
}: let
  # Sops *attribute* name for the GitHub PAT file. Must be one of `githubPatSecretAttrs` in
  # `modules/profiles/minimal/shells/sops-session-env.nix` (e.g. "github-token" or "gh-token").
  githubPatSecretAttrName = "github-token";
  home = config.home.homeDirectory;
  secretDir = "${home}/.config/sops-secrets";
  githubPatSecret = {
    key = "github_token";
    path = "${secretDir}/github-token";
  };
in {
  sops = {
    defaultSopsFile = dotfilesLib.sopsFile;
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
          path = "${secretDir}/agent-pat";
        };
      }
      // {
        "context7-api-key" = {
          key = "context7_api_key";
          path = "${home}/.config/context7/api-key";
        };
        "inception-api-key" = {
          key = "inception_api_key";
          path = "${secretDir}/inception-api-key";
        };
        "kagi-api-key" = {
          key = "kagi/api_key";
          path = "${home}/.kagi_api_key";
        };
        "kagi-session-token" = {
          key = "kagi/session_token";
          path = "${home}/.kagi_session_token";
        };
        "openrouter-api-key" = {
          key = "openrouter_api_key";
          path = "${secretDir}/openrouter-api-key";
        };
        "hf-token" = {
          key = "hf_token";
          path = "${secretDir}/hf-token";
        };
      };

    # Render ~/.kagi.toml from the kagi secrets so the `kagi` CLI's default
    # config carries credentials declaratively. Note: env vars exported by
    # sops-session-env.nix still take precedence over this file.
    templates."kagi.toml" = {
      path = "${home}/.kagi.toml";
      mode = "0600";
      content = ''
        [auth]
        api_key = "${config.sops.placeholder."kagi-api-key"}"
        session_token = "${config.sops.placeholder."kagi-session-token"}"
      '';
    };
  };
}
