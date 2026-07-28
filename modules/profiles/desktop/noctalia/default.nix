{
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hostConfigFile = host.noctaliaConfigFile or "config.toml";
  tomlFormat = pkgs.formats.toml { };
  # Import as attrset so Stylix can merge theme/wallpaper/font settings on top.
  # A raw path here conflicts with stylix's attrset definitions for the same option.
  baseSettings = tomlFormat.import (./config + "/${hostConfigFile}");
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;
    systemd.enable = false;
    validateConfig = true;
    # Source of truth: modules/profiles/desktop/noctalia/config/*.toml
    # (rebuild after edits). Stylix merges theme/wallpaper on top; GUI overrides
    # still land in ~/.local/state/noctalia/settings.toml.
    settings = lib.mkDefault baseSettings;
  };

  # Allow migration from the old live-symlink layout to HM-managed config.toml.
  xdg.configFile."noctalia/config.toml".force = true;

  # screen_recorder plugin shells out to gpu-screen-recorder (must be on PATH).
  home.packages = [ pkgs.gpu-screen-recorder ];
}
