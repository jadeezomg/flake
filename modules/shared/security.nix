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

  # User-facing secrets (paths under $HOME) and shell env exports live in
  # home-manager: `home/shared/security.nix` + `sops-shell-secrets.nix`.
  #
  # When you need activation-time or root-owned keys, add them here with the
  # flake's `sops-nix` NixOS/Darwin module, e.g.:
  #   sops.defaultSopsFile = ../../secrets/secrets.yaml;
  #   sops.age.keyFile = "…";
  #   sops.secrets.my-key = { … };
}
