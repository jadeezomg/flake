{
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}: let
  editorsEnabled = osConfig.dotfiles.profiles.apps.editors.enable or false;
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
    package = inputs.nixpkgs-zed.legacyPackages.${pkgs.system}.zed-editor; # package =
    #   if isDarwin && inputs ? nixpkgs-zed
    #   then inputs.nixpkgs-zed.legacyPackages.${pkgs.system}.zed-editor
    #   else pkgs.zed-editor;
  };
}
