{ ... }:

{
  # Shared programs configuration for both NixOS and Darwin
  # Note: These are system-level programs
  # For user-level program configuration, use Home Manager
  programs = {
    git.enable = true;
  };
}
