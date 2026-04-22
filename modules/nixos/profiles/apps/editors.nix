{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.editors;
in {
  config = lib.mkIf cfg.enable {
    # IDE packages that want a system-wide install on NixOS (so root/gdm can
    # resolve them too). HM-level settings for cursor/zed still live in
    # home/shared/apps/ides and are gated on the same flag.
    environment.systemPackages = with pkgs; [
      code-cursor
      zed-editor
    ];
  };
}
