{
  config,
  host,
  inputs,
  pkgs,
  ...
}:
let
  inherit (config.lib.dotfiles) mkLiveSymlink;

  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  extraPackages = import ./extra-packages.nix { inherit pkgs; };

  hostSettingsFile = host.noctaliaSettingsFile or "settings.toml";
  settingsDir = "${config.dotfiles.flakeRoot}/modules/profiles/desktop/noctalia/config";
in
{
  # `programs.noctalia` comes from Home Manager itself. Noctalia's own
  # `homeModules.default` declares the same option, so importing it here made
  # evaluation fail with "already declared". The two modules are the same code
  # (HM upstreamed it); only `validateConfig` was renamed to `checkConfig`.
  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;
    systemd.enable = false;
    checkConfig = true;
    # Only Stylix writes `settings` (theme, font, wallpaper), so the generated
    # ~/.config/noctalia/config.toml holds just those keys. ./config/settings.toml
    # is the full source of truth, live-symlinked below as the GUI layer.
    #
    # Do not feed settings.toml into `settings` again. When the GUI saves a
    # page, Noctalia drops every key that matches a lower layer. With
    # settings.toml as its own lower layer, unchanged keys matched themselves
    # and were dropped, and the next rebuild removed them from config.toml too.
    # That lost the panel glass mode and other settings (2026-10-24).
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
