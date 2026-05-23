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
      jujutsu
      jjui
      gh
      lazygit
      gh-dash

      # --- Task runners ---
      just
      mask
      act

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
      asciinema
    ];
  };
}
