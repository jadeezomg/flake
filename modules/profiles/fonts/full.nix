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
}: let
  cfg = config.dotfiles.profiles.fonts;
in {
  config = lib.mkIf (cfg.enable && cfg.full.enable) {
    fonts.packages = with pkgs; [
      alegreya
      anonymousPro
      atkinson-hyperlegible
      cabin
      cardo
      cascadia-code
      comfortaa
      commit-mono
      crimson
      dancing-script
      dejavu_fonts
      dosis
      eb-garamond
      fantasque-sans-mono
      fira
      fira-code
      fira-code-symbols
      fira-mono
      font-awesome
      garamond-libre
      geist-font
      gelasio
      hack-font
      ibm-plex
      inconsolata
      input-fonts
      iosevka-aile
      iosevka-bin
      jetbrains-mono
      julia-mono
      lato
      liberation_ttf
      libre-baskerville
      libre-franklin
      lmodern
      lora
      maple-mono.NF
      maple-mono.Normal-NF
      maple-mono.Normal-Variable
      maple-mono.variable
      merriweather
      monaspace
      montserrat
      nerd-fonts.blex-mono
      nerd-fonts.caskaydia-cove
      nerd-fonts.commit-mono
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.geist-mono
      nerd-fonts.go-mono
      nerd-fonts.hack
      nerd-fonts.inconsolata
      nerd-fonts.iosevka-term
      nerd-fonts.iosevka-term-slab
      nerd-fonts.jetbrains-mono
      nerd-fonts.liberation
      nerd-fonts.monaspace
      nerd-fonts.recursive-mono
      nerd-fonts.roboto-mono
      nerd-fonts.zed-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji-blob-bin
      office-code-pro
      open-sans
      oswald
      overpass
      paratype-pt-mono
      paratype-pt-sans
      poppins
      powerline-fonts
      powerline-symbols
      quicksand
      raleway
      recursive
      roboto
      roboto-mono
      source-code-pro
      source-sans-pro
      source-serif-pro
      ubuntu-classic
      victor-mono
      vollkorn
      work-sans
    ];
  };
}
