{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.integrations;
in
{
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
      services.flatpak.enable = true;

      # Register Flathub remote at activation time. Installing individual apps
      # is left to the user (`flatpak install flathub <app-id>`).
      system.activationScripts.flatpakSetup = ''
        export PATH="${config.system.path}/bin:''${PATH}"
        if ! flatpak remote-list 2>/dev/null | grep -q "flathub"; then
          echo "Adding Flathub remote..."
          flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
        fi
      '';
    })
  ];
}
