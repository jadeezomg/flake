{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.nix;
in {
  config = lib.mkIf cfg.enable {
    # `nil`/`nixd`/`nixfmt` are already pulled in via devenv.tools. This
    # profile only adds the lint-focused extras that a non-dev host (server)
    # wouldn't want.
    environment.systemPackages = with pkgs; [
      alejandra
      deadnix
      statix
    ];
  };
}
