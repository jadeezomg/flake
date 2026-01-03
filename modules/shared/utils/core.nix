{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # --- Core System Utilities ---
    coreutils # Basic GNU tools
    zoxide # Better cd

    # --- Build Essentials ---
    gnumake # Make files
    gnutls # GNU transport layer security library
    gcc # GNU compiler collection
    pkg-config # Package information finder

    # --- Version Control ---
    git
    jujutsu # Git-compatible DVCS
    jjui # Jujutsu UI
  ];
}
