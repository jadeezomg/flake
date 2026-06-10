{pkgs, ...}: {
  # --- sudo (NixOS + nix-darwin) ---
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=60 # Change default timeout for sudo
    Defaults pwfeedback           # Show asterisks when typing password
  '';

  # --- Encryption CLIs (system-wide) ---
  environment.systemPackages = with pkgs; [
    age
    sops
  ];
}
