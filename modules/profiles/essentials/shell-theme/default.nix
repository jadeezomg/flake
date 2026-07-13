# Prompt + shell theming (starship, nushell palette) — pushed by the
# essentials profile; palette comes from dotfilesLib.palette (lib/theme-palette.nix).
{ ... }: {
  imports = [
    ./starship.nix
    ./nushell-env.nix
  ];
}
