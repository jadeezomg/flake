# Homebrew side of the work profile (darwin-only leaf — `homebrew.*` doesn't
# exist on NixOS). Tap pins live in hosts/caya/default.nix (nix-homebrew).
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.work;
in {
  # HM configs for apps installed by the casks below (alt-tab, notunes, …),
  # plus mise shell integration (mise is a brew, installed in default.nix).
  home-manager.sharedModules = lib.mkIf cfg.enable [
    ./brew-casks
    ./mise-shell.nix
  ];

  homebrew = lib.mkIf cfg.enable {
    enable = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "uninstall";
      # Upgrades run during activation; transient network/CDN issues can
      # fail the switch — set to false if that bites.
      upgrade = true;
    };

    brews = [
      "rbenv" # Ruby version manager
      "ruby-build" # Ruby version installer for rbenv
      "trash" # Send files to Finder Trash from CLI
      "mise" # Polyglot dev tool/runtime version manager
    ];

    casks = [
      # --- Productivity ---
      "1password" # Password manager (Mac-specific GUI)
      "1password-cli" # 1Password CLI
      "raycast" # Spotlight replacement (Mac-specific)
      "notion" # Notes and collaboration
      "slack" # Team communication (simpler via Homebrew)
      "claude" # Claude Desktop

      # --- Browsers ---
      "zen" # Daily-driver browser
      "firefox"
      "google-chrome"

      # --- Utilities ---
      "dockdoor" # alt-tab replacement
      "middleclick" # Three-finger click utility (Mac-specific)
      "notunes" # Disable iTunes/Music auto-launch (Mac-specific)
      "linearmouse" # mouse options
      "finetune" # Per-app volume control
      "xykong/tap/flux-markdown" # md for peek
      "hyperkey" # rebind keys
      "handy" # Offline speech-to-text desktop app
      "shottr" # screenshot tool

      # --- Fonts (not in nixpkgs) ---
      "font-sf-mono"
      "font-sf-pro"

      # --- Design Resources ---
      "sf-symbols" # Apple SF Symbols
    ];

    masApps = {
      # Add Mac App Store apps here by ID (find via: mas search "App Name")
      # Example: "Xcode" = 497799835;
    };

    taps = builtins.attrNames (config.nix-homebrew.taps or {});
  };
}
