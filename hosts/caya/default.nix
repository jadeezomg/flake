{
  config,
  pkgs,
  inputs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
in {
  imports = [
    # Shared modules (work on both NixOS and Darwin)
    ../../modules/shared
    # Darwin-specific modules
    ../../modules/darwin
  ];

  # Caya (Darwin aarch64) specific configuration
  # TODO: Add caya-specific configuration

  # System configuration
  system.stateVersion = "25.11";
}
