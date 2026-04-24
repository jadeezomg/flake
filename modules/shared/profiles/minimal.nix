{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.minimal;
  minimalPackages = import ../../../lib/packages/minimal.nix pkgs;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = minimalPackages;
  };
}
