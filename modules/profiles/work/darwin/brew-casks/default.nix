{ ... }: {
  # Homebrew cask application configurations
  # These apps are installed via Homebrew but configured via home-manager
  #
  # `defaults.generated.nix` is captured from the live system by
  # `just darwin-defaults-sync`, which discovers domains from the installed cask
  # list. It deliberately skips any domain configured by hand in the files
  # below, so a hand-owned module always wins for the domains it claims.
  imports = [
    ./defaults.generated.nix
    ./alt-tab.nix
    ./notunes.nix
    ./scroll-reverser.nix
  ];
}
