# Homebrew side of the work profile (darwin-only leaf — `homebrew.*` doesn't
# exist on NixOS). Tap pins live in hosts/caya/default.nix (nix-homebrew).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.work;
in
{
  # Codiff (cask below) shells out to the Codex CLI and only looks for it on
  # PATH or inside Codex.app, neither of which exists here — codex comes from
  # the llm-agents overlay. CODIFF_CODEX_PATH overrides that lookup. It goes
  # through launchd rather than the shell env because Codiff is a GUI app:
  # apps launched from Finder/Dock/Spotlight never see shell exports.
  # modules/darwin re-runs `launchctl setenv` for these at every login, so the
  # value survives reboots. A store path (not /run/current-system/sw/bin) keeps
  # it valid even if the devenv.agents profile stops installing codex.
  launchd.user.envVariables = lib.mkIf cfg.enable {
    CODIFF_CODEX_PATH = "${pkgs.llm-agents.codex}/bin/codex";
  };

  home-manager.sharedModules = lib.mkIf cfg.enable [
    ./brew-casks
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
      "trash" # Send files to Finder Trash from CLI
    ];

    casks = [
      # --- Productivity ---
      "1password" # Password manager (Mac-specific GUI)
      "1password-cli" # 1Password CLI
      "notion" # Notes and collaboration
      "slack" # Team communication (simpler via Homebrew)
      "claude" # Claude Desktop
      "linear" # Linear Desktop

      # --- Browsers ---
      "firefox"
      "google-chrome"

      # --- Utilities ---
      "middleclick" # Three-finger click utility (Mac-specific)
      "notunes" # Disable iTunes/Music auto-launch (Mac-specific)
      "linearmouse" # mouse options
      "hyperkey" # rebind keys
      "handy" # Offline speech-to-text desktop app
      "shottr" # screenshot tool
      "nkzw-tech/tap/codiff" # Visual diff tool for Git changes (own tap)
      "vorssaint"

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

    taps = builtins.attrNames (config.nix-homebrew.taps or { });
  };
}
