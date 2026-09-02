# Core dev tooling — the system packages plus the HM half (mise).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.tools;
in
{
  config = lib.mkIf cfg.enable {
    # mise — polyglot tool/runtime version manager and task runner. mise is
    # inside the nix closure on both platforms, so home-manager generates the
    # shell activation snippets at build time. nushell gets a store path it can
    # `use`, which is why the writable-cache dance the Homebrew mise needed on
    # Darwin is gone.
    home-manager.sharedModules = [ { programs.mise.enable = true; } ];

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
      act
      watchexec

      # --- Code metrics & analysis ---
      tokei
      diffnav

      # --- Session recording ---
      asciinema
    ];
  };
}
