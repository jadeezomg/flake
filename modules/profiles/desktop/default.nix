{
  config,
  dotfilesLib,
  inputs,
  host,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  shell = host.desktopShell or cfg.shell;
  useDms = shell == "dms";
  useNoctalia = shell == "noctalia";
  useDmsGreeter = cfg.loginManager == "dms-greeter";
  dmsShell = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./dms/greeter-acl.nix
    ./gnome
    ./mime.nix
    ./noctalia/greeter.nix
    ./peripherals.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(useNoctalia && useDmsGreeter);
        message = "dms-greeter is DMS-only; use gdm or noctalia-greeter with the Noctalia shell.";
      }
    ];

    home-manager.sharedModules = [
      ./niri-hm.nix
      ./mango-hm.nix
      ./gnome/dconf.nix
      ./gnome/home.nix
      ./easyeffects.nix
    ]
    ++ lib.optionals useDms [
      ./dms
      ./dms/dankcalendar.nix
    ]
    ++ lib.optionals useNoctalia [
      ./noctalia
    ];

    programs = {
      dms-greeter = {
        enable = useDms && useDmsGreeter;
        compositor.name = "niri";
        configHome = host.homeDirectory;
        configFiles = [ "${host.homeDirectory}/.config/DankMaterialShell/settings.json" ];
      };

      niri.enable = true;

      # Second session next to niri, picked on the login screen.
      mango = {
        enable = true;
        # HDR is off (mango/outputs-desktop.conf). It needs Vulkan, which scenefx lacks.
        # Pure eval has no clock, so the nixpkgs pin date stands in for "6 months on".
        package = (dotfilesLib.expiry { inherit lib; } "modules/profiles/desktop/default.nix").recheckWhen {
          stale = lib.versionAtLeast pkgs.scenefx.version "0.6" || inputs.nixpkgs.lastModified >= 1807394400; # 2027-04-11
          reason = "check Mango HDR status. Is wlrfx/scenefx#192 (Vulkan) merged, and does mango ship blur and HDR together? If yes, enable HDR as mango/outputs-desktop.conf says. If no, move this date forward.";
        } pkgs.mango;
      };

      dank-material-shell = lib.mkIf useDms {
        enable = true;
        package = dmsShell;
        quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
        systemd = {
          enable = useDmsGreeter;
          restartIfChanged = true;
        };
        enableSystemMonitoring = true;
        enableVPN = true;
        enableDynamicTheming = true;
        enableAudioWavelength = true;
        enableCalendarEvents = false;
      };

      noctalia = lib.mkIf useNoctalia {
        enable = true;
        package = noctaliaPkg;
        systemd.enable = false;
        recommendedServices.enable = false;
      };
    };

    # mango starts mango-session.target, which pulls in graphical-session.target
    # and with it the shell unit. The nixpkgs module does not install it.
    systemd.packages = [ config.programs.mango.package ];

    services = {
      desktopManager.gnome.enable = true;
      gvfs.enable = true;
      tumbler.enable = true;
      power-profiles-daemon.enable = true;
      upower.enable = true;
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

    environment = {
      sessionVariables.XDG_CURRENT_DESKTOP = "niri:GNOME";

      etc."wayland-sessions/niri.desktop".text = ''
        [Desktop Entry]
        Name=Niri
        Comment=Start Niri Wayland Compositor
        Exec=${config.programs.niri.package}/bin/niri
        Type=Application
        DesktopNames=niri
      '';

      systemPackages = with pkgs; [
        libnotify
        nautilus
        xwayland-satellite
        (symlinkJoin {
          name = "handy";
          paths = [ pkgs.llm-agents.handy ];
          buildInputs = [ makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/handy --set GTK_THEME Adwaita:dark
          '';
        })
        wtype
        wl-clipboard
      ];
    };
  };
}
