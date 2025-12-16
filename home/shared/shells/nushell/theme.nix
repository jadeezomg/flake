{pkgs, ...}: let
  # Import theme colors
  themeColors = import ../../assets/theme/theme.nix;
in {
  programs.nushell.extraConfig = ''
    # Source the Birds of Paradise theme from nu_scripts
    source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu

    # Override background color after theme activation
    # The theme auto-activates, so we override immediately after
    $env.config.color_config = ($env.config.color_config | upsert background '${themeColors.bg-primary}')

    # Update terminal background color via OSC sequence
    let osc_screen_background_color = '11;'
    print -n $"(ansi -o $osc_screen_background_color)${themeColors.bg-primary}(char bel)\r"
  '';
}
