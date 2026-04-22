{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.tools;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # --- Build essentials (migrated from modules/shared/utils/core.nix) ---
      gnumake
      gnutls
      gcc
      gdb
      pkg-config

      # --- Version control ---
      git
      jujutsu
      jjui

      # --- Task runners ---
      just
      mask
      act

      # --- Git tools (delta lives in minimal) ---
      gh
      lazygit
      gitui
      gh-dash

      # --- Code metrics & analysis ---
      tokei

      # --- Package managers ---
      uv

      # --- Nix tooling (formatters + LSPs) ---
      nixfmt
      nil
      nixd

      # --- Container tools ---
      dive

      # --- Session recording ---
      asciinema_3
    ];
  };
}
