# Notes feature folder. App-specific packages and Home Manager settings live in
# sibling modules so Obsidian and Typora config stay grouped with their apps.
{
  isDarwin ? false,
  lib,
  ...
}:
{
  imports = [
    ./obsidian.nix
    ./typora
  ]
  # Whisp ships as a Flathub app, so it is Linux-only.
  ++ lib.optionals (!isDarwin) [ ./whisp.nix ];
}
