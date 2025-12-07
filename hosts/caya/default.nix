{
  config,
  pkgs,
  inputs,
  hostData,
  hostKey,
  user,
  ...
}:

let
  host = hostData.hosts.${hostKey} or { };
in
{
  imports = [
    # Shared modules (work on both NixOS and Darwin)
    ../../modules/shared
    # Darwin-specific modules
    ../../modules/darwin
  ];

  # Configure settings for existing macOS user account
  # The user must already exist in macOS (created via System Preferences)
  # This only configures the shell and other nix-darwin managed settings
  # It does NOT create the user - use your existing Apple account
  users.users.${user} = {
    name = user;
    home = host.homeDirectory or "/Users/${user}";
    shell = pkgs.nushell;
    # Note: Groups on Darwin work differently than NixOS
    # Most groups are managed by macOS, not nix-darwin
    # Only add groups that are created by nix-darwin or Homebrew
  };

  # Caya (Darwin aarch64) specific configuration
  # TODO: Add caya-specific configuration

  # System configuration
  system.stateVersion = 4; # Darwin state version
}
