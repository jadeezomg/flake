# Vicinae launcher (HM) — apps profile on Linux + Darwin.
# Linux: systemd autostart + niri Mod+Space toggle (keybinds-dms.kdl).
# Darwin: launchd autostart + skhd Option+Space.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  ext = inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system};

  # Store extensions previously installed via the GUI (store.vicinae.*).
  # https://docs.vicinae.com/nixos#configuring-extensions
  # systemd is in the store but omitted from vicinae-extensions.packages (dbus build).
  extensionNames = [
    "github"
    "it-tools"
    "nix"
    "podman"
    "process-manager"
    "protondb-search"
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "niri" ];

  vicinaeExtensions = map (name: ext.${name}) extensionNames;

  vicinaeSettings = {
    pop_to_root_on_close = true;
    activate_on_single_click = false;
    favicon_service = "twenty";
    font.rendering = "qt";
    launcher_window = {
      client_side_decorations.border_width = 0;
      compact_mode.enabled = false;
    };
    providers = {
      clipboard.preferences = {
        eraseOnStartup = false;
        ignorePasswords = false;
        monitoring = true;
      };
      core.entrypoints = {
        "report-bug".enabled = false;
        sponsor.enabled = false;
      };
      developer.enabled = false;
      power.entrypoints = {
        hibernate.enabled = false;
        "soft-reboot".enabled = false;
        suspend.enabled = false;
      };
      theme = {
        enabled = false;
        entrypoints.set.enabled = false;
      };
    };
  };

  vicinaeExe = "${config.home.path}/bin/vicinae";
in
{
  sops.templates."vicinae-github.json" = lib.mkIf (config.sops.secrets ? "github-token") {
    content = ''
      {
        "providers": {
          "@knoopx/github-0": {
            "preferences": {
              "personalAccessToken": "${config.sops.placeholder."github-token"}"
            }
          },
          "@knoopx/nix-0": {
            "preferences": {
              "githubToken": "${config.sops.placeholder."github-token"}"
            }
          }
        }
      }
    '';
    mode = "0600";
  };

  programs.vicinae = {
    enable = true;
    # nixpkgs ships vicinae for Linux and darwin (both cached) since 0.26.3;
    # the flake input is only kept for its HM/NixOS modules.
    package = pkgs.vicinae;
    # Zen native-messaging host wiring lives in apps.browsers/zen.
    enableFirefoxIntegration = false;
    extensions = vicinaeExtensions;
    settingOverrides = lib.mkIf (config.sops.secrets ? "github-token") [
      config.sops.templates."vicinae-github.json".path
    ];
    systemd = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 1;
      };
    };
    settings = vicinaeSettings;
  };

  home = {
    # Drop GUI store copies so Vicinae does not list duplicates after switch.
    activation.removeVicinaeStoreExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for ext in ${lib.concatStringsSep " " extensionNames}; do
        $DRY_RUN_CMD rm -rf "${config.xdg.dataHome}/vicinae/extensions/store.vicinae.''${ext}"
      done
    '';

    # Vicinae has no global hotkeys; bind Option+Space via skhd.
    # HM has no programs.skhd — wire the daemon + ~/.skhdrc ourselves.
    packages = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ pkgs.skhd ];

    file.".skhdrc" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      text = ''
        # Option+Space toggles Vicinae; mirrors niri Mod+Space on Linux.
        # NB: Hyper+Space (cmd+alt+ctrl+shift) is owned by Handy — keep clear.
        alt - space : ${vicinaeExe} toggle
      '';
    };
  };

  launchd.agents = {
    # Nix-built Vicinae on macOS skips onboarding login items — start the server
    # ourselves. https://docs.vicinae.com/quickstart/macos
    vicinae = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [
          vicinaeExe
          "server"
        ];
        RunAtLoad = true;
        KeepAlive = true;
      };
    };

    skhd = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.skhd}/bin/skhd" ];
        RunAtLoad = true;
        KeepAlive = true;
      };
    };
  };
}
