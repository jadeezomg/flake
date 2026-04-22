{
  config,
  lib,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
  workCfg = config.dotfiles.profiles.work;
in {
  nix.enable = false;
  system.primaryUser = user;
  users.users.${user} = {
    name = user;
    home = host.homeDirectory or "/Users/${user}";
    shell = pkgs.nushell;
  };

  security.pam.services.sudo_local.touchIdAuth = true;
  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
    Defaults env_keep += "TERMINFO TERMINFO_DIRS"
    Defaults env_keep += "LANG LANGUAGE LC_*"
    Defaults timestamp_timeout=15
  '';

  services.tailscale.enable = true;

  homebrew = lib.mkIf workCfg.enable {
    enable = true;

    onActivation = {
      autoUpdate = false;
      cleanup = "uninstall";
      upgrade = true;
    };

    brews = [
      "rbenv" # Ruby version manager
      "ruby-build" # Ruby version installer for rbenv
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
      "alt-tab" # Window switcher (Mac-specific)
      "middleclick" # Three-finger click utility (Mac-specific)
      "notunes" # Disable iTunes/Music auto-launch (Mac-specific)
      "scroll-reverser" # Reverse scroll direction (Mac-specific)
      "finetune" # Per-app volume control

      # --- Development ---
      "handy" # Offline speech-to-text desktop app

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
