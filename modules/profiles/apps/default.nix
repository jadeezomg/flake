{
  config,
  isDarwin ? false,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps;
in
{
  # Sub-category options are declared in ../default.nix. Each category file
  # holds its system packages with platform extras inline; media.nix is a
  # Linux-only leaf because `programs.obs-studio` doesn't exist on darwin.
  imports = [
    ./browsers
    ./comms.nix
    ./editors
    ./files
    ./notes
    ./terminals
  ]
  ++ lib.optionals (!isDarwin) [ ./media.nix ];

  # The category files read `apps.enable` directly. Only notes keeps its own
  # flag, because other modules still read it.
  config = lib.mkMerge (
    [
      (lib.mkIf cfg.enable {
        home-manager.sharedModules = [ ./vicinae.nix ];

        dotfiles.profiles.apps.notes.enable = lib.mkDefault true;
      })
    ]
    ++ lib.optionals (!isDarwin) [
      {
        # The upstream module defaults this privileged wrapper on. Tie it to
        # the apps profile so headless hosts neither build nor install Vicinae.
        programs.vicinae.input-server = {
          inherit (cfg) enable;
          package = pkgs.vicinae;
        };
        programs.kdeconnect.enable = cfg.enable;
      }
    ]
  );
}
