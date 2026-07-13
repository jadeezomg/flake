{
  config,
  lib,
  pkgs,
  user,
  ...
}:
{
  config = lib.mkMerge [
    (lib.mkIf config.dotfiles.profiles.devenv.containers.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };

      # Enable lingering so the user-level systemd manager (and rootless
      # podman.socket at $XDG_RUNTIME_DIR/podman/podman.sock) keeps running
      # without an active GUI login. Required for nono-sandboxed agents to
      # reach podman over SSH or headless sessions — see ADR-0001.
      users.users.${user}.linger = true;
    })

    {
      virtualisation.vmVariant = {
        virtualisation = {
          memorySize = 8192;
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

        users.groups.vmtest = { };

        services.xserver.displayManager.autoLogin = {
          enable = true;
          user = "vmtest";
        };
      };
    }
  ];
}
