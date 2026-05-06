{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.rust;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rustup
      bacon
      cargo-info
      rusty-man
    ];
  };
}
