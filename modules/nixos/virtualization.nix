{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  config = lib.mkMerge [
    # --- Podman (devenv.containers only) ---
    (lib.mkIf config.dotfiles.profiles.devenv.containers.enable {
      virtualisation.podman = {
        enable = true;
        # `docker` → `podman` for scripts that invoke the docker binary.
        dockerCompat = true;
        # Expose Podman where Docker clients expect the socket (members
        # need the `podman` group).
        dockerSocket.enable = true;
      };

      # Enable lingering so the user-level systemd manager (and rootless
      # podman.socket at $XDG_RUNTIME_DIR/podman/podman.sock) keeps running
      # without an active GUI login. Required for nono-sandboxed agents to
      # reach podman over SSH or headless sessions — see ADR-0001.
      users.users.${user}.linger = true;
    })

    # --- `nixos-rebuild build-vm` variant ---
    # Applied only when the vmVariant is evaluated (not in regular system
    # activation). Defines a throwaway test user + display-manager autologin.
    {
      virtualisation.vmVariant = {
        virtualisation = {
          memorySize = 8192; # 8 GiB RAM
          cores = 4;
          graphics = true;
        };

        users.users.vmtest = {
          isNormalUser = true;
          initialPassword = "test";
          group = "vmtest";
          extraGroups = [
            "wheel"
            "video"
            "audio"
            "networkmanager"
          ];
          shell = pkgs.bash;
        };

        users.groups.vmtest = {};

        services.xserver.displayManager.autoLogin = {
          enable = true;
          user = "vmtest";
        };
      };
    }
  ];
}
