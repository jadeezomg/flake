{pkgs, ...}: {
  # No nix-darwin equivalent of NixOS `virtualisation.podman`; use nixpkgs builds.
  # `podman-compose` lives in shared `languages/docker.nix`.
  home.packages = with pkgs; [
    podman
    podman-desktop
  ];
}
