# GUI counterpart of devenv.containers (podman CLI/TUI stay headless-side).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devgui.containers;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.podman-desktop];
  };
}
