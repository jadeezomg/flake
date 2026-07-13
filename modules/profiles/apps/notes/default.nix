# Notes feature folder. App-specific packages and Home Manager settings live in
# sibling modules so Obsidian and Typora config stay grouped with their apps.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.notes;
in
{
  imports = [
    ./obsidian.nix
    ./typora
  ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optionals (!isDarwin) [ pkgs.libreoffice ];
  };
}
