# Full font catalogue — the merged union of the old system list
# (modules/shared/fonts.nix) and the old Home Manager catalogue
# (home/shared/assets/fonts/fonts.nix), deduped, as one system-level list.
# `fonts.packages` exists on both NixOS and nix-darwin, so no platform leaf.
# The Stylix-referenced baseline lives in ./default.nix; the server keeps
# only that baseline (`fonts.full.enable = false` on mini).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.fonts;
in
{
  config = lib.mkIf (cfg.enable && cfg.full.enable) {
    fonts.packages = with pkgs; [
      ibm-plex
      input-fonts
      iosevka-aile
      iosevka-bin
      julia-mono
      maple-mono.NF
      maple-mono.variable
      monaspace
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.go-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.monaspace
      nerd-fonts.zed-mono
      powerline-fonts
      powerline-symbols
    ];
  };
}
