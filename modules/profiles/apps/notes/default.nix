# Notes feature folder — system half here, Home Manager half in ./home.nix
# (pushed to every user via sharedModules when the profile is enabled, so the
# HM side needs no osConfig gate).
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.notes;
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [./home.nix];

    environment.systemPackages = lib.optionals (!isDarwin) (with pkgs; [
      libreoffice
    ]);
  };
}
