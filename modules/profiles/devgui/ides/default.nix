# IDEs feature folder — system packages (NixOS-wide install so root/gdm can
# resolve them) plus the rich HM configs in ./vscode and ./zed.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devgui.ides;
in
{
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ./vscode
      ./zed
    ];

    environment.systemPackages = lib.optionals (!isDarwin) (
      with pkgs;
      [
        vscode
        zed-editor
      ]
    );
  };
}
