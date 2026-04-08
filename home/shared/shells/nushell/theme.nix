{pkgs, ...}: let
  # Import theme colors
  themeColors = import ../../assets/theme/theme.nix;
in {
  programs.nushell.extraConfig = ''
    # Only apply visual terminal theming in interactive sessions.
    if ($nu.is-interactive) {
      # Source the Birds of Paradise theme from nu_scripts.
      source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu

      # Override background color after theme activation.
      # The theme auto-activates, so we override immediately after.
      $env.config.color_config = ($env.config.color_config | upsert background '${themeColors.bg-primary}')

      # Do not print OSC sequences here; tools like Zed parse `nu` JSON output.
      # Emitting escape codes during startup breaks their env deserialization.
    }
  '';
}
