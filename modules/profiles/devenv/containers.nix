{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.containers;
in {
  config = lib.mkIf cfg.enable {
    # CLI/TUI only — podman-desktop lives in devgui.containers.
    environment.systemPackages = with pkgs;
      [
        dockfmt
        dockerfile-language-server
        podman
        podman-tui
        podman-compose
      ]
      ++ lib.optionals isDarwin [
        # `docker` → `podman` shim, mirroring NixOS `dockerCompat`.
        (pkgs.writeShellScriptBin "docker" ''exec ${pkgs.podman}/bin/podman "$@"'')
      ];
  };
}
