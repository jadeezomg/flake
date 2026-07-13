{
  config,
  isDarwin ? false,
  lib,
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

  # Convenience: enabling apps.enable activates every category the current
  # workstation hosts ship today. Slimmer hosts (work laptop, server) should
  # set the unwanted sub-flags to `false` explicitly after enabling apps.
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ ./vicinae.nix ];

    dotfiles.profiles.apps = {
      browsers.enable = lib.mkDefault true;
      terminals.enable = lib.mkDefault true;
      editors.enable = lib.mkDefault true;
      files.enable = lib.mkDefault true;
      comms.enable = lib.mkDefault true;
      notes.enable = lib.mkDefault true;
      media.enable = lib.mkDefault true;
    };
  };
}
