{...}: {
  # AltTab - Windows-style alt-tab for macOS
  # https://alt-tab-macos.netlify.app/

  # Configure AltTab preferences via defaults
  targets.darwin.defaults."com.lwouis.alt-tab-macos" = {
    # Start at login
    startAtLogin = true;

    # Appearance
    appearanceSize = 0; # 0 = medium
    appearanceStyle = 0; # 0 = thumbnails

    # Show settings
    appsToShow = 0; # 0 = all apps
    showTitles = 2; # 2 = show titles
    hideAppBadges = false;
    hideStatusIcons = false;

    # Preview settings
    previewFocusedWindow = true;

    # Menubar icon
    menubarIconShown = false;

    # Shortcut (Control key)
    holdShortcut = "\\U2303";

    # Update settings
    updatePolicy = 1; # 1 = automatically check for updates
  };
}
