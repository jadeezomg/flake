{ ... }: {
  # Headless-server behaviour is gated inline in
  # modules/nixos/{boot,networking}.nix via
  # `config.dotfiles.profiles.server.enable`.
  #
  # This profile body is intentionally minimal — `server.enable` is a steering-
  # wheel toggle, not a package set. Per-host opt-out of desktop/integrations is
  # done explicitly in `hosts/<name>/profiles.nix`.
}
