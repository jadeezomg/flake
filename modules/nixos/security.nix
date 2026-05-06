{pkgs, ...}: {
  # --- sudo ---
  security.sudo.enable = true;

  # --- Keyrings (PAM) ---
  security.pam.services = {
    login.enableGnomeKeyring = true;
    # DMS greeter is the active authentication service when using greetd+dms.
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
