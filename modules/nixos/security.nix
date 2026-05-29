{pkgs, ...}: {
  # --- sudo ---
  security.sudo.enable = true;

  # --- Keyrings (PAM) ---
  security.pam.services = {
    login.enableGnomeKeyring = true;
    # DMS greeter PAM when loginManager = "dms-greeter"; GDM uses gdm-password / gdm-fingerprint.
    dms-greeter = {
      enableGnomeKeyring = true;
      startSession = true;
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
