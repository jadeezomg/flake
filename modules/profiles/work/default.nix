{
  config,
  isDarwin ? false,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.work;
in {
  # darwin.nix holds the homebrew side of the work profile; the
  # `homebrew.*` namespace only exists on darwin, hence the import gate.
  imports = lib.optionals isDarwin [./darwin.nix];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.postman
      pkgs.gws
      pkgs.workato-platform-cli
    ];
  };
}
