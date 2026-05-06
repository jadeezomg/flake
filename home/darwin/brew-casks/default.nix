{...}: {
  # Homebrew cask application configurations
  # These apps are installed via Homebrew but configured via home-manager
  imports = [
    ./alt-tab.nix
    ./notunes.nix
    ./scroll-reverser.nix
  ];
}
