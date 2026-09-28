{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # CLI/TUI only — podman-desktop lives in devgui.containers.
  packages =
    pkgs: with pkgs; [
      dockfmt
      dockerfile-language-server
      dive
      podman
      podman-tui
      podman-compose
    ];
  darwinPackages = pkgs: [
    # `docker` → `podman` shim, mirroring NixOS `dockerCompat`.
    (pkgs.writeShellScriptBin "docker" ''exec ${pkgs.podman}/bin/podman "$@"'')
  ];
} args
