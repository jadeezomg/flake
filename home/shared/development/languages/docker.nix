{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- OCI / Podman (same Dockerfiles and image registries) ---
    dockfmt
    dockerfile-language-server
    podman-compose
  ];
}
