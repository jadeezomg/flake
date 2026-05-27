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
  dmsShell = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell.overrideAttrs (old: {
    # DMS' greeter user picker currently shells out to:
    #   getent passwd | awk -F: '$3>=1000 && $3<60000 && $1!="nobody" ...'
    # Nix build users are intentionally static system users at 30001..30032,
    # so they pass that UID-only filter even though NixOS already marks them
    # as display-manager hiddenUsers. Keep the build users for Nix, hide them
    # at the DMS seam until upstream respects hiddenUsers or shell filtering.
    postInstall =
      (old.postInstall or "")
      + ''
        substituteInPlace $out/share/quickshell/dms/Services/GreeterUsersService.qml \
          --replace-fail \
            '$3>=1000 && $3<60000 && $1!=\"nobody\"' \
            '$3>=1000 && $3<60000 && $1!=\"nobody\" && $1 !~ /^nixbld[0-9]+$/'
      '';
  });
  handyCpuOnly =
    (inputs.handy.legacyPackages.${pkgs.stdenv.hostPlatform.system}.handy).overrideAttrs
    (old: {
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
      package = dmsShell;
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
      # inputs.handy.legacyPackages.${pkgs.stdenv.hostPlatform.system}.handy
    ];
  };
}
