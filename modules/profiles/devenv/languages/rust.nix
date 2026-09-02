{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.languages.rust;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rustup
      bacon
      clippy
      cargo
      cargo-generate
      cargo-nextest
      cargo-seek
      cargo-info
      rusty-man
    ];
  };
}
