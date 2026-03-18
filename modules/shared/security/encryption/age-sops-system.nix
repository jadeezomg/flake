{
  config,
  lib,
  user,
  ...
}: let
  userHome =
    (config.users.users.${user}.home or "/home/${user}");

  # NixOS tends to define `group`; Darwin may not, so fall back to `user`.
  userGroupOpt =
    (config.users.users.${user}.group or null);
in {
  # Decrypt secrets using SOPS + age (sops-nix).
  #
  # This provisions the GitHub API token at:
  #   ~/.config/nix/github-token
  #
  # so `nix flake update` / `nix flake lock` can authenticate against GitHub
  # and avoid unauthenticated API rate limits.
  sops = {
    defaultSopsFile = ../../../../secrets/secrets.yaml;

    age = {
      generateKey = false;
      keyFile = "${userHome}/.config/sops/age/keys.txt";
    };

    secrets."github-token" = {
      key = "github_token";
      path = "${userHome}/.config/nix/github-token";
      owner = user;
      mode = "0400";
    }
    // lib.optionalAttrs (userGroupOpt != null) {
      secrets."github-token".group = userGroupOpt;
    };
  };
}

