{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./helix
  ];

  programs.helix = {
    enable = true;
    package = pkgs.helix;
  };

  # Wayland clipboard for `:clipboard-yank` / external paste (Linux only).
  home.packages = lib.optionals pkgs.stdenv.isLinux [pkgs.wl-clipboard];
}
