# Prompt theming (starship) — pushed by the essentials profile; palette comes
# from config.dotfiles.theme.palette (lib/home/theme.nix). Nushell colors are Stylix's
# (../../theme/stylix.nix), and nushell itself is configured in
# ../../minimal/shells/core/nushell.nix.
{ ... }: {
  imports = [
    ./starship.nix
  ];
}
