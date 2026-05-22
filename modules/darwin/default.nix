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
  homeDir = host.homeDirectory or "/Users/${user}";

  xdgVars = {
    XDG_CONFIG_HOME = "${homeDir}/.config";
    XDG_CACHE_HOME = "${homeDir}/.cache";
    XDG_DATA_HOME = "${homeDir}/.local/share";
    XDG_STATE_HOME = "${homeDir}/.local/state";
    XDG_BIN_HOME = "${homeDir}/.local/bin";
  };

  setenvCommands =
    lib.concatStringsSep " && "
    (lib.mapAttrsToList (k: v: "launchctl setenv ${k} ${lib.escapeShellArg v}") xdgVars);
in {
  nix.enable = false;
  system.primaryUser = user;
  users.users.${user} = {
    name = user;
    home = homeDir;
    shell = pkgs.nushell;
  };

  # home/darwin/default.nix sets xdg.enable = true so home-manager places
  # configs under ~/.config. macOS/launchd doesn't export XDG_* by default,
  # so shells launched outside a zsh chain (nushell as login shell, bash/fish
  # spawned from a terminal app) miss their config dir entirely — nu falls
  # back to ~/Library/Application Support/nushell and runs with stock defaults.
  #
  # `launchd.user.envVariables` only fires `launchctl setenv` from the
  # activation script (lost on reboot). A LaunchAgent with RunAtLoad re-runs
  # the setenv at every user login so the vars survive reboot.
  launchd.user.envVariables = xdgVars;

  launchd.user.agents.xdg-env = {
    serviceConfig = {
      Label = "org.nix-community.xdg-env";
      ProgramArguments = ["/bin/sh" "-c" setenvCommands];
      RunAtLoad = true;
    };
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
      # Avoid upgrading the full brew graph during activation; transient
      # network/CDN issues can fail the whole switch.
      upgrade = true;
    };

    brews = [
      "rbenv" # Ruby version manager
      "ruby-build" # Ruby version installer for rbenv
      "trash" # Send files to Finder Trash from CLI
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
      # "alt-tab" # Window switcher (Mac-specific)
      "dockdoor" # alt-tab replacement
      "middleclick" # Three-finger click utility (Mac-specific)
      "notunes" # Disable iTunes/Music auto-launch (Mac-specific)
      # "scroll-reverser" # Reverse scroll direction (Mac-specific)
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
