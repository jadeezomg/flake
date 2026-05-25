{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.dotfiles.profiles.desktop;
  # whisper-rs-sys 0.15 (via transcribe-rs's whisper-vulkan feature) references
  # coopmat1 SPIR-V symbols that vulkan-shaders-gen doesn't emit on current
  # nixpkgs. Patch Cargo.toml to use whisper-cpp until upstream fixes it.
  handyCpuOnly = (inputs.handy.legacyPackages.${pkgs.stdenv.hostPlatform.system}.handy).overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src-tauri/Cargo.toml \
          --replace-fail \
            'transcribe-rs = { version = "0.3.3", features = ["whisper-vulkan"] }' \
            'transcribe-rs = { version = "0.3.3", features = ["whisper-cpp"] }'
      '';
  });
in {
  imports = [inputs.niri.nixosModules.niri];

  config = lib.mkIf cfg.enable {
    # --- Greeter (replaces GDM for reliable multi-monitor Wayland login) ---
    programs.dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/${user}";
      configFiles = ["/home/${user}/.config/DankMaterialShell/settings.json"];
    };

    # --- Niri compositor (niri-unstable from niri-flake) ---
    programs.niri = {
      enable = true;
      package = pkgs.niri-unstable;
    };

    # --- DankMaterialShell (DMS) ---
    # xdg.configFile is handled in home/nixos/desktop/dms.nix (Home Manager).
    programs.dank-material-shell = {
      enable = true;
      quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
      systemd = {
        enable = true;
        restartIfChanged = true;
      };
      enableSystemMonitoring = true; # dgop widgets
      enableVPN = true;
      enableDynamicTheming = true; # matugen
      enableAudioWavelength = true; # cava
      enableCalendarEvents = true; # khal
    };

    programs.dsearch = {
      enable = true;
      systemd = {
        enable = true;
        target = "default.target";
      };
    };

    # --- Supporting services ---
    services = {
      desktopManager.gnome.enable = true; # GNOME session kept as fallback DE
      gvfs.enable = true;
      tumbler.enable = true;
      power-profiles-daemon.enable = true; # DMS widgets need this
      upower.enable = true;

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

    # Wayland session file so greeter can offer Niri as a session.
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
      handyCpuOnly
    ];
  };
}
