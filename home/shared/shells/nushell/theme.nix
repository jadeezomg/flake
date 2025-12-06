{ inputs, ... }:

{
  programs.nushell.extraConfig = ''
    # Source the Birds of Paradise theme from nu_scripts
    source ${inputs.nu-scripts}/themes/nu-themes/birds-of-paradise.nu
  '';
}

