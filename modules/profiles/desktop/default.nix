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
  shell = host.desktopShell or cfg.shell;
  useDms = shell == "dms";
  useNoctalia = shell == "noctalia";
  useDmsGreeter = cfg.loginManager == "dms-greeter";
  useGdm = cfg.loginManager == "gdm";
  dmsShell = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./dms-greeter-acl.nix
    ./peripherals.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(useNoctalia && useDmsGreeter);
        message = "Noctalia shell requires GDM (dms-greeter is DMS-only).";
      }
    ];

    home-manager.sharedModules = [
      ./niri-hm.nix
      ./dconf.nix
      ./gdm-session.nix
    ]
    ++ lib.optionals useDms [
      ./dms
      ./dankcalendar.nix
    ]
    ++ lib.optionals useNoctalia [
      ./noctalia
    ];

    programs.dms-greeter = {
      enable = useDms && useDmsGreeter;
      compositor.name = "niri";
      configHome = host.homeDirectory;
      configFiles = [ "${host.homeDirectory}/.config/DankMaterialShell/settings.json" ];
    };

    programs.niri.enable = true;

    programs.dank-material-shell = lib.mkIf useDms {
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

    programs.noctalia = lib.mkIf useNoctalia {
      enable = true;
      package = noctaliaPkg;
      systemd.enable = false;
      recommendedServices.enable = false;
    };

    services = {
      displayManager.gdm = lib.mkIf useGdm {
        enable = true;
      };

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

    environment.sessionVariables.XDG_CURRENT_DESKTOP = "niri:GNOME";

    environment.etc."wayland-sessions/niri.desktop".text = ''
      [Desktop Entry]
      Name=Niri
      Comment=Start Niri Wayland Compositor
      Exec=${config.programs.niri.package}/bin/niri
      Type=Application
      DesktopNames=niri
    '';

    environment.systemPackages =
      with pkgs;
      [
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
      ]
      ++ lib.optionals useNoctalia [
        satty # shell.screenshot pipe_to_command in noctalia/config.toml
      ];
  };
}
