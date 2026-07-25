# Desktop peripherals — audio (pipewire), printing, graphics libs, display /
# input tooling. Was unconditional Linux base; headless hosts don't need any
# of it, so it's gated on the desktop profile.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
in
{
  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;

    # --- Audio (pipewire stack) ---
    services = {
      services.solaar = {
        enable = true;
        window = "hide"; # Show the window on startup (show, *hide*, only [window only])
        batteryIcons = "regular"; # Which battery icons to use (*regular*, symbolic, solaar)
        extraArgs = "";
      };
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        wireplumber.enable = true;
      };
      # --- Printing ---
      printing.enable = true;
    };
    security.rtkit.enable = true;

    environment.systemPackages = with pkgs; [
      mission-center

      # --- Audio admin ---
      alsa-utils
      pamixer
      pavucontrol
      playerctl
      wireplumber

      # --- Graphics libs (pulled in by various desktop apps) ---
      glib
      gsettings-desktop-schemas
      libGL
      libGLU
      libva
      mesa

      # --- Display / video ---
      autorandr
      brightnessctl
      wdisplays

      # --- Input ---
      evtest
      libinput

      # --- Power ---
      upower
    ];
  };
}
