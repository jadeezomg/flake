{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.languages.ruby;
in
{
  config = lib.mkIf cfg.enable {
    # NOTE: On darwin `chruby` still comes in via Homebrew for better
    # bash/zsh compatibility — keep that split intact.
    environment.systemPackages = [ pkgs.ruby ];
  };
}
