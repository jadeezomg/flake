{pkgs, ...}: {
  programs.nushell.extraConfig = ''
    # Source the Birds of Paradise theme from nu_scripts
    source ${pkgs.nu_scripts}/themes/nu-themes/birds-of-paradise.nu
  '';
}
