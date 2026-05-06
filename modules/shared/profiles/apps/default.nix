{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.apps;
in {
  # Sub-category options are declared in ../default.nix and consumed directly
  # by Home Manager / nixos modules / darwin homebrew. Only categories that
  # ship cross-platform *system* packages need a file here (currently: notes).
  imports = [
    ./notes.nix
  ];

  # Convenience: enabling apps.enable activates every category the current
  # workstation hosts ship today. Slimmer hosts (work laptop, server) should
  # set the unwanted sub-flags to `false` explicitly after enabling apps.
  config = lib.mkIf cfg.enable {
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
