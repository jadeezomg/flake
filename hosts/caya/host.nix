let
  inherit (import ../lib.nix) darwinUser;
in {
  hostname = "caya";
  description = "Jadee Caya Darwin Host";
  username = darwinUser.username;
  system = "aarch64-darwin";
  homeDirectory = darwinUser.homeDirectory or "/Users/${darwinUser.username}";
  stateVersion = darwinUser.stateVersion or "25.11";
  buildCores = 6;
  # Darwin user config is simpler - just shell configuration
  # The user must already exist in macOS
  user = darwinUser.user or {};
}
