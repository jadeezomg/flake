_: {
  dotfiles.profiles = {
    devenv.enable = true;
    devgui.enable = true;
    apps.enable = true;
    work.enable = true;
    # Near-black main background (lib/theme-palette-variants.nix), as on
    # desktop and framework.
    theme.variant = "black";
  };
}
