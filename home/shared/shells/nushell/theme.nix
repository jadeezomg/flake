{pkgs, ...}: let
  # Import theme colors
  themeColors = import ../../assets/theme/theme.nix;
in {
  programs.nushell.extraConfig = ''
    # Only source the birds-of-paradise theme when stdout is a real TTY.
    # The theme's `update terminal` emits OSC 10/11/12 sequences via `print -n`,
    # which break non-terminal consumers like Zed's shell-environment capture
    # (Zed redirects stdout to a pipe, so `test -t 1` returns false there).
    if $nu.is-interactive {
      ^sh -c 'test -t 1'
      if $env.LAST_EXIT_CODE == 0 {
        source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu
        $env.config.color_config = ($env.config.color_config | upsert background '${themeColors.bg-primary}')
      }
    }
  '';
}
