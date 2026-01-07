{pkgs, ...}: {
  # AltTab - Windows-style alt-tab for macOS
  # https://alt-tab-macos.netlify.app/

  # Configure AltTab preferences via defaults
  targets.darwin.defaults."com.lwouis.alt-tab-macos" = {
    # Appearance
    appearanceSize = 0;
    appearanceStyle = 0;

    # Show settings
    appsToShow = 0;
    showTitles = 2;
    hideAppBadges = false;
    hideStatusIcons = false;

    previewFocusedWindow = true;

    updatePolicy = 0;
    crashPolicy = 1;
  };
}
