{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.integrations;
in
{
  # nix-flatpak extends the `services.flatpak` namespace with declarative
  # `remotes` and `packages`; nixpkgs only ships the daemon. The import is
  # unconditional (this file is Linux-only already) and everything it adds is
  # gated behind `services.flatpak.enable`, so headless hosts stay unaffected.
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  config = lib.mkMerge [
    # --- AppImage ---
    # See https://wiki.nixos.org/wiki/Appimage
    (lib.mkIf (cfg.enable && cfg.appimage.enable) {
      programs.appimage = {
        enable = true;
        binfmt = true;
      };
    })

    # --- Flatpak + Flathub remote ---
    (lib.mkIf (cfg.enable && cfg.flatpak.enable) {
      # nix-flatpak's `remotes` default already registers Flathub, so no
      # activation script is needed. Individual apps are declared next to their
      # own profile via `services.flatpak.packages`, which merges across modules.
      services.flatpak.enable = true;

      # Deliberately left at `false`: these hosts also carry hand-installed
      # flatpaks this flake does not declare, and `true` would uninstall them.
      # The cost is that dropping an app from `packages` leaves it on disk —
      # follow up with `flatpak uninstall --system <app-id>`.
      services.flatpak.uninstallUnmanaged = false;
    })
  ];
}
