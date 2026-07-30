{
  config,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.dotfiles) mkLiveSymlink;

  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  extraPackages = import ./extra-packages.nix { inherit pkgs; };

  hostSettingsFile = host.noctaliaSettingsFile or "settings.toml";
  settingsDir = "${config.dotfiles.flakeRoot}/modules/profiles/desktop/noctalia/config";

  # Read as an attrset so Stylix can merge theme/wallpaper/font settings on top.
  # A raw path here conflicts with stylix's attrset definitions for the same option.
  #
  # Not `(pkgs.formats.toml {}).import` — that attribute does not exist (the
  # format only provides `generate` and `type`). It never threw because the
  # mkDefault below was priority-filtered away, so this was never forced.
  baseSettings = builtins.fromTOML (builtins.readFile (./config + "/${hostSettingsFile}"));
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;
    systemd.enable = false;
    validateConfig = true;
    # Source of truth: ./config/settings.toml, live-symlinked below. It feeds
    # both of noctalia's layers — here as the declarative base that HM renders
    # to ~/.config/noctalia/config.toml (with Stylix merged in), and directly as
    # the state-dir settings.toml, which per `noctalia config validate` docs
    # "overrides" that base. One file, so the two layers cannot disagree.
    #
    # mkDefault has to be pushed down to each leaf, not wrapped around the whole
    # attrset. Stylix defines nested paths (settings.theme.source, …) at normal
    # priority, and the module system filters a whole-attrset mkDefault out
    # against those *before* type merging — which silently reduced the generated
    # config.toml to Stylix's 6 sections out of 35 here. Per-leaf defaults merge
    # instead, so Stylix wins only the keys it actually sets.
    settings = lib.mapAttrsRecursive (_: value: lib.mkDefault value) baseSettings;
  };

  # Allow migration from the old live-symlink layout to HM-managed config.toml.
  xdg.configFile."noctalia/config.toml".force = true;

  # The settings the GUI writes are the ones that actually win, so point them at
  # the checkout instead of leaving them in unversioned state. Verify the link
  # survived a write with `just symlink-check` — an app that saves via
  # write-temp-then-rename would replace it with a plain file and drift again.
  home.file.".local/state/noctalia/settings.toml" =
    mkLiveSymlink "${settingsDir}/${hostSettingsFile}";

  home.packages = extraPackages;
}
