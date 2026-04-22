{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  userHome =
    config.users.users.${user}.home or "/home/${user}";

  # NixOS tends to define `group`; Darwin may not, so fall back to user only.
  userGroupOpt =
    config.users.users.${user}.group or null;

  mkSecret = keyName: relPath:
    {
      key = keyName;
      path = "${userHome}/${relPath}";
      owner = user;
      mode = "0400";
    }
    // lib.optionalAttrs (userGroupOpt != null) {
      group = userGroupOpt;
    };
in {
  # --- sudo ---
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=60 # Change default timeout for sudo
    Defaults pwfeedback           # Show asterisks when typing password
  '';

  # --- Encryption tooling ---
  environment.systemPackages = with pkgs; [
    age
    sops
  ];

  # --- sops-nix (system) ---
  # Secrets decrypt at activation; paths sit under the primary user's home so
  # userspace tools (nix, ctx7) find them without a /run/secrets hop.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      generateKey = false;
      keyFile = "${userHome}/.config/sops/age/keys.txt";
    };
    secrets = {
      github-token = mkSecret "github_token" ".config/nix/github-token";
      context7-api-key = mkSecret "context7_api_key" ".config/nix/context7-api-key";
      inception-api-key = mkSecret "inception_api_key" ".config/nix/inception-api-key";
      kagi-api-key = mkSecret "kagi_api_key" ".config/nix/kagi-api-key";
    };
  };
}
