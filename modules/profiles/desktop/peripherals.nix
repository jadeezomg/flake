# Desktop peripherals — audio (pipewire), printing, graphics libs, display /
# input tooling. Was unconditional Linux base; headless hosts don't need any
# of it, so it's gated on the desktop profile.
{
  config,
  dotfilesLib,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;

  # OpenLogi (https://github.com/AprilNEA/OpenLogi) can replace Solaar once
  # nixpkgs ships a version that knows the c54d receiver (added in 0.7.7). The
  # upstream flake has it, but builds Rust and GPUI from source with no cache.
  #
  # Checked 2026-11-02: nixpkgs has openlogi 0.6.25, upstream 0.8.20.
  solaarEnable =
    (dotfilesLib.expiry { inherit lib; } "modules/profiles/desktop/peripherals.nix").recheckWhen
      {
        stale = lib.versionAtLeast pkgs.openlogi.version "0.7.7";
        reason = "nixpkgs ships openlogi >= 0.7.7, which knows the c54d receiver; decide whether to replace Solaar (drop programs.solaar and its udev rules, add pkgs.openlogi with its udev rules and an openlogi-agent user service).";
      }
      true;

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

    # --- Logitech (peripherals) ---
    programs.solaar = {
      enable = solaarEnable;
      userService = {
        enable = true;
        window = "hide"; # Show the window on startup (show, *hide*, only [window only])
        batteryIcons = "regular"; # Which battery icons to use (*regular*, symbolic, solaar)
        extraArgs = [ ];
      };
    };

    services = {
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

      udev.extraRules = ''
        # Start/stop solaar with the G Pro X Superlight 2 Lightspeed receiver.
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="${gpxSuperlight2Receiver}", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="solaar.service"
        ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="046d", ENV{ID_MODEL_ID}=="${gpxSuperlight2Receiver}", RUN+="${stopSolaar}"

        # binepad CandyPad (4249:4350) — grant access to the QMK raw HID
        # interface (usage page 0xFF60) so VIA can remap keys/encoders.
        # Nodes are root-only by default.
        #
        # GROUP/MODE do the real work here: extraRules lands in 99-local.rules,
        # but systemd's uaccess builtin already ran at 70-uaccess.rules, so a
        # bare TAG+="uaccess" is set too late to produce an ACL. GROUP/MODE are
        # applied after all rules are read, so they hold at any priority.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="4249", ATTRS{idProduct}=="4350", GROUP="input", MODE="0660", TAG+="uaccess"
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

      # --- Desktop schemas ---
      glib
      gsettings-desktop-schemas

      # --- Display / video ---
      autorandr
      brightnessctl
      wdisplays

      # --- Input ---
      evtest
      libinput
    ];
  };
}
