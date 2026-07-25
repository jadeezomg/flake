# Desktop peripherals — audio (pipewire), printing, graphics libs, display /
# input tooling. Was unconditional Linux base; headless hosts don't need any
# of it, so it's gated on the desktop profile.
{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;

  # G Pro X Superlight 2 Lightspeed dongle (046d:c54d).
  gpxSuperlight2Receiver = "c54d";

  solaarHasReceiver = pkgs.writeShellScript "solaar-has-receiver" ''
    set -eu
    ${pkgs.usbutils}/bin/lsusb -d 046d:${gpxSuperlight2Receiver} | ${pkgs.gnugrep}/bin/grep -Eq .
  '';

  # udev RUN as root → user bus (ATTRS vanish on remove; use ID_* from the db).
  stopSolaar = "${pkgs.systemd}/bin/systemctl --no-block --user --machine=${user}@.host stop solaar.service";
in
{
  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;

    services = {
      # --- Logitech (peripherals) ---
      solaar = {
        enable = true;
        window = "hide"; # Show the window on startup (show, *hide*, only [window only])
        batteryIcons = "regular"; # Which battery icons to use (*regular*, symbolic, solaar)
        extraArgs = "";
      };
      # --- Audio (pipewire stack) ---
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

      # Start/stop solaar with the G Pro X Superlight 2 Lightspeed receiver.
      udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="${gpxSuperlight2Receiver}", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="solaar.service"
        ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="046d", ENV{ID_MODEL_ID}=="${gpxSuperlight2Receiver}", RUN+="${stopSolaar}"
      '';
    };
    security.rtkit.enable = true;

    # Skip autostart when the Superlight 2 receiver is absent; udev starts on plug.
    systemd.user.services.solaar.serviceConfig.ExecCondition = solaarHasReceiver;

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
