{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.languages.nix;
in
{
  config = lib.mkIf cfg.enable {
    # The editor toolchain (`nixd` LSP + `nixfmt`) plus treefmt (via
    # nixfmt-tree) and lint-focused extras that a non-dev host (server)
    # wouldn't want.
    environment.systemPackages = with pkgs; [
      nixd
      nixfmt
      nixfmt-tree
      deadnix
      statix
    ];
  };
}
