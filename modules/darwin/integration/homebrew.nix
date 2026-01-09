{
  config,
  pkgs,
  ...
}: {
  # Homebrew configuration for Darwin
  # Packages that don't have good Nix equivalents or are Mac-specific

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      cleanup = "uninstall";
      upgrade = true;
    };

    # Command-line tools (formulas)

    brews = [
      # Dependencies that are better managed by Homebrew on macOS
      # These are often required by casks or system integrations
      "rbenv" # Ruby version manager
      "ruby-build" # Ruby version installer for rbenv
    ];

    # GUI applications (casks)
    # These are Mac-specific apps that are better installed via Homebrew
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

      # --- Development ---
      "docker-desktop" # Docker Desktop for Mac (renamed from docker)

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

    taps = builtins.attrNames (config.nix-homebrew.taps or {});
  };
}
