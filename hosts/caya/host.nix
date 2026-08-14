let
  inherit (import ../lib.nix) darwinUser;
in
{
  hostname = "caya";
  description = "Jadee Caya Darwin Host";
  # No ssh alias — caya is the work laptop and nothing dials into it. Opting out
  # explicitly rather than by omission, since hosts/hosts.nix otherwise defaults
  # sshAddress to the hostname.
  sshAddress = null;
  inherit (darwinUser) username;
  system = "aarch64-darwin";
  homeDirectory = darwinUser.homeDirectory or "/Users/${darwinUser.username}";
  stateVersion = darwinUser.stateVersion or "26.05";
  buildCores = 6;
  # Darwin user config is simpler - just shell configuration
  # The user must already exist in macOS
  user = darwinUser.user or { };
}
