{pkgs, ...}: {
  programs.nushell.extraConfig = ''
    # Source the Birds of Paradise theme from nu_scripts
    source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu

    # Override background color to match Cursor theme (#372725 instead of #2a1f1d)
    $env.config.color_config.background = '#372725'
  '';
}
