{pkgs, ...}: {
  programs.nushell.extraConfig = ''
    # Source the Birds of Paradise theme from nu_scripts
    source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu

    # Override background color after theme activation
    # The theme auto-activates, so we override immediately after
    $env.config.color_config = ($env.config.color_config | upsert background '#372725')

    # Update terminal background color via OSC sequence
    let osc_screen_background_color = '11;'
    print -n $"(ansi -o $osc_screen_background_color)#372725(char bel)\r"
  '';
}
