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
      # bash — bash-language-server is the front-end; it calls shellcheck for
      # diagnostics and shfmt for formatting, both resolved from PATH.
      # Wired into helix, Zed, and VSCode.
      bash-language-server
      shellcheck
      shfmt
    ];
  };
}
