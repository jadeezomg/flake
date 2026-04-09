{...}: {
  virtualisation.podman = {
    enable = true;
    # `docker` → `podman` for scripts that invoke the docker binary
    dockerCompat = true;
    # Expose Podman where Docker clients expect the socket (members need `podman` group)
    dockerSocket.enable = true;
  };
}
