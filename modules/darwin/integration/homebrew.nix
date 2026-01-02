{pkgs, ...}: {
  # Homebrew configuration for Darwin
  # Packages that don't have good Nix equivalents or are Mac-specific

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false; # Don't auto-update Homebrew
      cleanup = "zap"; # Uninstall packages not declared here
      upgrade = false; # Don't auto-upgrade packages
    };

    # Command-line tools (formulas)
    # NOTE: Most CLI tools have been migrated to Nix packages
    # Only keep Mac-specific tools or those with better Homebrew support here
    brews = [
      # Dependencies that are better managed by Homebrew on macOS
      # These are often required by casks or system integrations
    ];

    # GUI applications (casks)
    # These are Mac-specific apps that are better installed via Homebrew
    # NOTE: Removed duplicates - already in Nix: ghostty, notion-app, zed, cursor, firefox (NixOS)
    casks = [
      # --- Productivity ---
      "1password" # Password manager (Mac-specific GUI)
      "1password-cli" # 1Password CLI
      "raycast" # Spotlight replacement (Mac-specific)
      "notion" # Notes and collaboration
      "slack" # Team communication (simpler via Homebrew)

      # --- Browsers ---
      "google-chrome" # Chrome browser
      "zen"

      # --- Utilities ---
      "alt-tab" # Window switcher (Mac-specific)
      "middleclick" # Three-finger click utility (Mac-specific)
      "notunes" # Disable iTunes/Music auto-launch (Mac-specific)
      "scroll-reverser" # Reverse scroll direction (Mac-specific)

      # --- Fonts ---
      # Apple San Francisco fonts (not available in Nix)
      "font-sf-mono"
      "font-sf-pro"

      # --- Design Resources ---
      "sf-symbols" # Apple SF Symbols
    ];

    # Mac App Store apps
    masApps = {
      # Add Mac App Store apps here by ID
      # Find app IDs with: mas search "App Name"
      # Example:
      # "Xcode" = 497799835;
    };

    # Taps (third-party repositories)
    taps = [
      # homebrew/cask-fonts is deprecated - fonts are now in main casks
    ];

    # NOTE: Removed duplicates already in Nix: ghostty, zed, cursor, zen-browser (via flake)
    # NOTE: The following fonts from Homebrew are available in Nix and should NOT be added here:
    # - font-hack-nerd-font (nerd-fonts.hack in Nix)
    # - font-iosevka (pkgs.iosevka in Nix)
    # - font-iosevka-aile (custom package in Nix)
    # - font-iosevka-etoile (custom package in Nix)
    # - font-iosevka-nerd-font (nerd-fonts.iosevka in Nix)
    # - font-symbols-only-nerd-font (nerd-fonts in Nix)
    # These are currently disabled for Darwin due to font directory issues but will be re-enabled.
  };
}
