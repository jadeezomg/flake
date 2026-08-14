{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.languages.shell;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # bash
      bash-language-server
      shfmt
      shellcheck

      # nushell
      nufmt
      nu_scripts
    ];
  };
}
