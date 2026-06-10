# IDEs feature folder — system packages (NixOS-wide install so root/gdm can
# resolve them) plus the rich HM configs in ./cursor and ./zed.
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
    home-manager.sharedModules = [./cursor ./zed];

    environment.systemPackages = lib.optionals (!isDarwin) (with pkgs; [
      code-cursor
      zed-editor
    ]);
  };
}
