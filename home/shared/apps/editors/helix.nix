{
  lib,
  osConfig,
  pkgs,
  ...
}: {
  # Settings / languages / keymaps in ./helix are pure option values, safe to
  # keep unconditionally — without `enable = true` they're inert.
  imports = [
    ./helix
  ];

  programs.helix = lib.mkIf (osConfig.dotfiles.profiles.apps.editors.enable or false) {
    enable = true;
    package = pkgs.helix;
  };

  # Wayland clipboard for `:clipboard-yank` / external paste (Linux only).
  home.packages = lib.mkIf (osConfig.dotfiles.profiles.apps.editors.enable or false) (
    lib.optionals pkgs.stdenv.isLinux [pkgs.wl-clipboard]
  );
}
