{ host, ... }:
{
  imports = [
    ./environment.nix
    ./security.nix
    ./shells.nix
  ];
  documentation.man.enable = true;

  # Host specific. Comes from hosts/<name>/host.nix and also feeds
  # home.stateVersion in parts/hosts.nix. Do not change it on an installed host.
  system.stateVersion = host.stateVersion;
}
