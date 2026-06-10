# Prompt + shell theming (starship, nushell palette) — pushed by the
# essentials profile; palette source is ../../theme/theme.nix.
{...}: {
  imports = [
    ./starship.nix
    ./nushell-env.nix
  ];
}
