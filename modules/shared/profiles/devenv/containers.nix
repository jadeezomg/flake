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
        podman-compose
      ]
      ++ lib.optionals isDarwin [
        # nix-darwin has no `virtualisation.podman` equivalent, so the
        # binaries ship as regular system packages.
        podman
        podman-desktop
        # `docker` → `podman` shim, mirroring NixOS `dockerCompat`.
        (pkgs.writeShellScriptBin "docker" ''exec ${pkgs.podman}/bin/podman "$@"'')
      ];
  };
}
