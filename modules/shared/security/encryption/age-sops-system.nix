{
  config,
  lib,
  user,
  ...
}: let
  userHome =
    config.users.users.${user}.home or "/home/${user}";

  # NixOS tends to define `group`; Darwin may not, so fall back to `user`.
  userGroupOpt =
    config.users.users.${user}.group or null;
in {
  sops = {
    defaultSopsFile = ../../../../secrets/secrets.yaml;

    age = {
      generateKey = false;
      keyFile = "${userHome}/.config/sops/age/keys.txt";
    };

    secrets.github-token =
      {
        key = "github_token";
        path = "${userHome}/.config/nix/github-token";
        owner = user;
        mode = "0400";
      }
      // lib.optionalAttrs (userGroupOpt != null) {
        group = userGroupOpt;
      };

    secrets.context7-api-key =
      {
        key = "context7_api_key";
        path = "${userHome}/.config/nix/context7-api-key";
        owner = user;
        mode = "0400";
      }
      // lib.optionalAttrs (userGroupOpt != null) {
        group = userGroupOpt;
      };

    secrets.inception-api-key =
      {
        key = "inception_api_key";
        path = "${userHome}/.config/nix/inception-api-key";
        owner = user;
        mode = "0400";
      }
      // lib.optionalAttrs (userGroupOpt != null) {
        group = userGroupOpt;
      };

    secrets.kagi-api-key =
      {
        key = "kagi_api_key";
        path = "${userHome}/.config/nix/kagi-api-key";
        owner = user;
        mode = "0400";
      }
      // lib.optionalAttrs (userGroupOpt != null) {
        group = userGroupOpt;
      };
  };
}
