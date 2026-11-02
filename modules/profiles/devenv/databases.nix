{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # Database client tooling. Server daemons belong to a host's own
  # services (mini-nix/services), not to this profile.
  packages = pkgs: [
    pkgs.rainfrog # TUI client
  ];
} args
