{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    nerd-fonts.zed-mono
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term-slab
  ];
}

