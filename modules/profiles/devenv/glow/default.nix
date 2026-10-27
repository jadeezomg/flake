# glow config with a Birds-of-Paradise style. glow has no Stylix target, so
# theme.nix renders a glamour style from config.dotfiles.theme.palette, and
# glow.yml points glow at it. The yazi opener and the lazygit G keys read the
# same config. glow itself installs from ../tools.nix.
{
  config,
  dotfilesLib,
  lib,
  options,
  ...
}:
let
  styleFile = "glow/birds-of-paradise.json";

  # The hand-made theme exists only because Stylix has no glow target. When a
  # Stylix update adds one, the guard warns and turns this config off, so the
  # Stylix target owns glow (theme-structure skill: Stylix ownership rule).
  ownTheme =
    (dotfilesLib.expiry { inherit lib; } "modules/profiles/devenv/glow/default.nix").expireWhen
      {
        fixed = lib.hasAttrByPath [ "stylix" "targets" "glow" ] options;
        reason = "Stylix now has a glow target (stylix.targets.glow). Delete modules/profiles/devenv/glow, its entry in devenv/default.nix, and its line in the theme-structure skill.";
        fallback = false;
      }
      true;
in
{
  config = lib.mkIf ownTheme {
    xdg.configFile.${styleFile}.text = builtins.toJSON (
      import ./theme.nix { inherit (config.dotfiles.theme) palette; }
    );

    # glow wrote these values itself on its first start. Only `style` is new.
    xdg.configFile."glow/glow.yml".text = ''
      style: "${config.xdg.configHome}/${styleFile}"
      mouse: false
      pager: false
      width: 80
      all: false
    '';
  };
}
