# Shared path definitions used across all shells
{
  # Common directory paths
  commonPaths = {
    home = "$HOME";
    config = "$HOME/.config";
    downloads = "$HOME/Downloads";
    dotfiles = "$HOME/.dotfiles";
    flake = "$HOME/.dotfiles/flake";
    localBin = "$HOME/.local/bin";
    cargoBin = "$HOME/.cargo/bin";
  };

  # Nix-specific paths
  nixPaths = {
    wrappersBin = "/run/wrappers/bin";
    nixProfile = "$HOME/.nix-profile/bin";
    userProfile = "/etc/profiles/per-user/$USER/bin";
    systemSw = "/run/current-system/sw/bin";
    defaultProfile = "/nix/var/nix/profiles/default/bin";
  };
}
