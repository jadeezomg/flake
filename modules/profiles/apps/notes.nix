{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.notes;
in {
  # The obsidian package + vault config is owned by Home Manager
  # (home/shared/apps/notes) via programs.obsidian, gated on the same flag.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optionals (!isDarwin) (with pkgs; [
      libreoffice
    ]);
  };
}
