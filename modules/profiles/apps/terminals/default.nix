{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.terminals;
in
{
  config = lib.mkIf cfg.enable {
    # HM halves — plain Home Manager modules, pushed to every user when the
    # profile is on (./ghostty.nix branches on isDarwin internally).
    home-manager.sharedModules = [
      ./ghostty.nix
      ./kitty.nix
    ];

    # Linux-only (ghostty is broken on darwin in nixpkgs; terminal apps on
    # macOS come from homebrew / HM configs instead).
    environment.systemPackages = lib.optionals (!isDarwin) (
      with pkgs;
      [
        ghostty
        kitty
      ]
    );
  };
}
