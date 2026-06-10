{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  editorsEnabled = osConfig.dotfiles.profiles.devgui.ides.enable or false;
in {
  imports = [
    ./extensions.nix
    ./keybinds.nix
    ./languages.nix
    ./settings.nix
    ./tasks.nix
    ./theme.nix
  ];

  programs.zed-editor = lib.mkIf editorsEnabled {
    enable = true;
    package = pkgs.zed-editor;
  };
}
