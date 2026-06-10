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
    environment.systemPackages = with pkgs;
      [
        dockfmt
        dockerfile-language-server
        podman
        podman-desktop
        podman-tui
        podman-compose
      ]
      ++ lib.optionals isDarwin [
        # `docker` → `podman` shim, mirroring NixOS `dockerCompat`.
        (pkgs.writeShellScriptBin "docker" ''exec ${pkgs.podman}/bin/podman "$@"'')
      ];
  };
}
