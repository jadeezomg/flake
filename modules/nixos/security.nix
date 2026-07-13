{
  pkgs,
  config,
  ...
}:
let
  # pam_keyinit gives each login session its own kernel session keyring.
  # Without it (bare WM / greetd, no display-manager auto-unlock) processes
  # share the volatile per-uid keyring and lose "possession" of keys stored
  # there — which breaks proton-pass-cli's linux-keyutils backend with
  # `NoStorageAccess(AccessDenied)`. `optional` so a failure never blocks login.
  keyinitRule = loginuidOrder: {
    keyinit = {
      control = "optional";
      modulePath = "${config.security.pam.package}/lib/security/pam_keyinit.so";
      args = [
        "force"
        "revoke"
      ];
      # Run right after pam_loginuid (so the keyring binds the right uid) and
      # before pam_systemd. order MUST be relative — a constant could be
      # silently reordered by a nixpkgs update and lock you out.
      order = loginuidOrder + 1;
    };
  };
in
{
  # --- sudo ---
  security.sudo.enable = true;

  # --- Keyrings (PAM) ---
  security.pam.services = {
    login = {
      enableGnomeKeyring = true;
      rules.session = keyinitRule config.security.pam.services.login.rules.session.loginuid.order;
    };
    # DMS greeter PAM when loginManager = "dms-greeter"; GDM uses gdm-password / gdm-fingerprint.
    dms-greeter = {
      enableGnomeKeyring = true;
      startSession = true;
      rules.session = keyinitRule config.security.pam.services.dms-greeter.rules.session.loginuid.order;
    };
  };

  # --- System packages (auth + secureboot) ---
  environment.systemPackages = with pkgs; [
    # Password management
    proton-pass
    proton-pass-cli
    # SecureBoot key management — kernels/efi binaries are signed against this
    sbctl
  ];
}
