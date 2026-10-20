{ ... }: {
  # Homebrew cask application configurations
  # These apps are installed via Homebrew but configured via home-manager
  #
  # Each domain is declared by hand as `targets.darwin.defaults."<domain>"` in
  # the files below. Capture from the live system used to be automated by a
  # `darwin-defaults` script writing `defaults.generated.nix`; that was removed,
  # so add new domains here directly. The one exception is Vorssaint: its
  # values live in data/vorssaint.nix, which `just vorssaint-sync` writes.
  imports = [
    ./notunes.nix
    ./vorssaint.nix
  ];
}
