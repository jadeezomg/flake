{
  config,
  lib,
  pkgs,
  ...
}:
let
  loginManager = config.dotfiles.profiles.desktop.loginManager;
  useDmsGreeter = loginManager == "dms-greeter";
  useGdm = loginManager == "gdm";
in
{
  environment.systemPackages = with pkgs; [ fprintd ];

  services.fprintd.enable = true;

  # Greeter PAM stacks are gated on the login manager so the toggle in
  # profiles.nix can be flipped either way without touching this file. Defining
  # a stack for a greeter that is not running would otherwise emit a stray
  # /etc/pam.d entry, and the dms-greeter rule below reads an option that only
  # exists while that greeter is enabled.
  security.pam.services = lib.mkMerge [
    {
      login.fprintAuth = lib.mkForce true;
      sudo.fprintAuth = true;
    }

    (lib.mkIf useDmsGreeter {
      # fprintAuth defaults to services.fprintd.enable (true), and its default
      # rule order puts fprintd BEFORE unix — so password-alone parks on the
      # fingerprint prompt. Move it after unix so password-alone succeeds and
      # fingerprint stays a fallback.
      dms-greeter = {
        fprintAuth = true;
        rules.auth.fprintd.order = config.security.pam.services.dms-greeter.rules.auth.unix.order + 10;
      };

      # greetd (which authenticates the actual DMS login over IPC) deliberately
      # gets nothing here. Upstream now builds its stack with
      # `useDefaultRules = false` and a single `substack login` for auth, so it
      # has neither a `unix` rule to order against nor an `fprintd` rule to
      # move — it inherits both from the `login` stack forced above. The old
      # `greetd.rules.auth.fprintd.order = …unix.order + 10` line predates that
      # change and referenced an attribute that no longer exists, which failed
      # this host's evaluation outright; re-adding it would break the switch
      # back to dms-greeter.
    })

    (lib.mkIf useGdm {
      gdm-password.fprintAuth = lib.mkForce true;
      gdm-fingerprint.fprintAuth = lib.mkForce true;
    })
  ];
}
