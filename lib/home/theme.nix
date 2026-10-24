# Home Manager side of the palette variant. The theme profile sets
# dotfiles.theme.variant from dotfiles.profiles.theme.variant
# (modules/profiles/theme/default.nix). Modules read the colors from
# config.dotfiles.theme.palette instead of dotfilesLib.palette, so they follow
# the variant of the host.
{
  config,
  dotfilesLib,
  lib,
  ...
}:
{
  options.dotfiles.theme = {
    variant = lib.mkOption {
      type = lib.types.enum (builtins.attrNames dotfilesLib.paletteVariants);
      default = "brown";
      description = "Palette variant from lib/theme-palette-variants.nix.";
    };

    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = dotfilesLib.paletteVariants.${config.dotfiles.theme.variant};
      defaultText = lib.literalExpression "dotfilesLib.paletteVariants.\${config.dotfiles.theme.variant}";
      description = "The palette of the selected variant.";
    };
  };
}
