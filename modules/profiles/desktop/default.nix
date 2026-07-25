{
  config,
  inputs,
  host,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  useDmsGreeter = cfg.loginManager == "dms-greeter";
  useGdm = cfg.loginManager == "gdm";
  dmsShell = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
in
{
  imports = [
    ./dms-greeter-acl.nix
    ./peripherals.nix
  ];

  config = lib.mkIf cfg.enable {
    # HM halves: DMS/niri live-symlink wiring (./dms), dconf user settings,
    # and GDM session glue.
    home-manager.sharedModules = [
      ./dms
      ./dankcalendar.nix
      ./dconf.nix
      ./gdm-session.nix
    ];

    # --- Login manager: set dotfiles.profiles.desktop.loginManager per host ---
    programs.dms-greeter = {
      enable = useDmsGreeter;
      compositor.name = "niri";
      configHome = host.homeDirectory;
      configFiles = [ "${host.homeDirectory}/.config/DankMaterialShell/settings.json" ];
    };

    programs.niri.enable = true;

    # --- DankMaterialShell (DMS) ---
    # xdg.configFile is handled in ./dms (Home Manager half).
    programs.dank-material-shell = {
      enable = true;
      package = dmsShell;
      quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
      systemd = {
        # System-wide unit lands in graphical-session.target; breaks GDM greeter.
        enable = useDmsGreeter;
        restartIfChanged = true;
      };
      enableSystemMonitoring = true; # dgop widgets
      enableVPN = true;
      enableDynamicTheming = true; # matugen
      enableAudioWavelength = true; # cava
      enableCalendarEvents = false; # DMS calendar is unused; avoid khal/vdirsyncer
    };

    # --- Supporting services ---
    services = {
      displayManager.gdm = lib.mkIf useGdm {
        enable = true;
      };

      desktopManager.gnome.enable = true; # GNOME session kept as fallback DE
      gvfs.enable = true;
      tumbler.enable = true;
      power-profiles-daemon.enable = true; # DMS widgets need this
      upower.enable = true;
      # GNOME/graphical-desktop default these on; unused here and expensive.
      orca.enable = lib.mkForce false;
      speechd.enable = false;

      xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "intl";
        };
      };
    };
    # Niri is primary; include GNOME so gnome-control-center detects a compatible session.
    environment.sessionVariables.XDG_CURRENT_DESKTOP = "niri:GNOME";

    # Wayland session file so GDM / greeter can offer Niri as a session.
    environment.etc."wayland-sessions/niri.desktop".text = ''
      [Desktop Entry]
      Name=Niri
      Comment=Start Niri Wayland Compositor
      Exec=${config.programs.niri.package}/bin/niri
      Type=Application
      DesktopNames=niri
    '';

    environment.systemPackages = with pkgs; [
      libnotify
      nautilus
      # Niri auto-spawns xwayland-satellite for X11 apps when it's in PATH.
      # See: https://github.com/YaLTeR/niri/wiki/Xwayland
      xwayland-satellite
      # Framework enables nixpkgsConfig.rocmSupport; Handy's GPU path is
      # Vulkan/ggml, so skip ORT-MIGraphX (~8GiB ROCm) and keep CPU onnxruntime.
      (handy.override {
        onnxruntime = onnxruntime.override { rocmSupport = false; };
      })
    ];
  };
}
