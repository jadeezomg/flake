# Shared environment variables used across all shells
{
  # Common environment variables
  commonEnv = {
    EDITOR = "zeditor";
    VISUAL = "zeditor";
    BROWSER = "zen";
    PAGER = "bat";
    BAT_THEME = "TwoDark";
  };

  # Common PATH additions (relative paths that need shell-specific expansion)
  commonPathAdditions = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.nix-profile/bin"
    "/etc/profiles/per-user/$USER/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
  ];
}
