{ config, pkgs, ... }:

{
  # Environment module that imports all package categories
  # Packages are organized by category in their respective modules:
  # - modules/utils/ - Text utilities, nix tools, etc.
  # - modules/development/ - IDEs and development tools
  # - modules/security/ - Security and authentication tools
  # - modules/fonts/ - Font packages
}

