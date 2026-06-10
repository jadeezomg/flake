# IDE system packages (NixOS-wide install so root/gdm can resolve them).
# The rich HM configs still live in home/shared/apps/ides (Phase 7 tier 4)
# and gate on this same flag via osConfig.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devgui.ides;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optionals (!isDarwin) (with pkgs; [
      code-cursor
      zed-editor
    ]);
  };
}
