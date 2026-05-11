{
  config,
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.dotfiles.profiles.desktop;
  # Handy override: whisper-rs-sys 0.15.0 (pulled via transcribe-rs's
  # `whisper-vulkan` feature) generates ggml-vulkan.cpp references to coopmat1
  # SPIR-V shader symbols (`matmul_id_subgroup_*_cm1_*`) that the bundled
  # vulkan-shaders-gen does not emit on current nixpkgs (shaderc / Vulkan SDK
  # combo). Build CPU-only until upstream fixes it; revisit when whisper-rs-sys
  # > 0.15 lands or handy's transcribe-rs feature is overridable.
  # handyCpuOnly = (inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
  #   postPatch =
  #     (old.postPatch or "")
  #     + ''
  #       substituteInPlace src-tauri/Cargo.toml \
  #         --replace-fail \
  #           'transcribe-rs = { version = "0.3.3", features = ["whisper-vulkan"] }' \
  #           'transcribe-rs = { version = "0.3.3", features = ["whisper-cpp"] }'
  #     '';
  # });
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

      # Handy — offline speech-to-text. Tracked from upstream flake until
      # nixpkgs ships it; Darwin uses brew cask `handy`.
      # CPU-only override (Vulkan whisper currently broken upstream — see top of file).
      # handyCpuOnly
      inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
