{
  config,
  host ? {},
  hostKey ? "unknown",
  isDarwin ? false,
  lib,
  ...
}: {
  # Linux-only leaves are gated at import level (not mkIf) because their
  # option namespaces (programs.steam, services.flatpak, …) don't exist on
  # darwin. `isDarwin` comes from specialArgs, so this is legal in `imports`.
  imports =
    [
      ./minimal.nix
      ./essentials.nix
      ./apps
      ./devenv
      ./work
      ./server.nix
    ]
    ++ lib.optionals (!isDarwin) [
      ./desktop.nix
      ./gaming.nix
      ./integrations.nix
    ];

  options.dotfiles.profiles = let
    inherit (lib) mkEnableOption mkOption types;

    enableOn = description:
      mkEnableOption description
      // {
        default = true;
      };
  in {
    minimal.enable = enableOn "the minimal profile (system core + sandbox-safe shells + daily-driver CLIs)";

    essentials = {
      enable = enableOn "the essentials profile (Starship prompt, HM widgets, system env, Nix workstation tooling)";
    };

    apps = {
      enable = mkEnableOption "the apps meta-profile";
      browsers.enable = mkEnableOption "apps.browsers (zen-browser; firefox/chrome live in work)";
      terminals.enable = mkEnableOption "apps.terminals (ghostty, kitty)";
      editors.enable = mkEnableOption "apps.editors (helix; cursor/zed are HM-only large configs)";
      files.enable = mkEnableOption "apps.files (zathura via HM on NixOS; nautilus/filezilla in nixos modules)";
      comms.enable = mkEnableOption "apps.comms (protonmail-desktop, etc.)";
      notes.enable = mkEnableOption "apps.notes (obsidian)";
      media.enable = mkEnableOption "apps.media (pear-desktop, future media players)";
    };

    devenv = {
      enable = mkEnableOption "the devenv meta-profile";
      tools.enable = mkEnableOption "devenv.tools (git, just, gh, lazygit, delta, jujutsu, etc.)";
      cloud.enable = mkEnableOption "devenv.cloud (awscli2, awslogs, gws)";
      llm = {
        agents.enable = mkEnableOption "devenv.llm.agents (opencode, claude-code, context7, kagi, ...) and the flake `data/agents/skills/` install";
        hosting.enable = mkEnableOption "devenv.llm.hosting (vllm, lmstudio — Linux-only realistically)";
      };
      containers.enable = mkEnableOption "devenv.containers (podman, podman-desktop, dive)";
      databases.enable = mkEnableOption "devenv.databases (rainfrog, dbeaver-bin)";
      languages = mkOption {
        type = types.attrsOf (types.submodule {
          options.enable = mkEnableOption "this language sub-profile";
        });
        default = {};
        description = ''
          Per-language opt-ins. Each entry maps a language name to a small
          submodule with a single `enable` flag; the corresponding file in
          `modules/profiles/devenv/languages/<name>.nix` wires the
          actual package set behind `lib.mkIf cfg.enable`.

          When `devenv.enable = true` every currently-active language is
          mkDefault-enabled; override per-host with
          `dotfiles.profiles.devenv.languages.<name>.enable = false;`.
        '';
      };
    };

    gaming.enable = mkEnableOption "the gaming profile (Steam stack — Linux only)";

    work.enable = mkEnableOption "the work profile (workato + postman + gws + AWS CLI; firefox/chrome via homebrew on darwin)";

    server.enable = mkEnableOption "the server profile (parked: postgresql, redis — no host imports yet, see Q9)";

    # Linux-only profiles — options declared here so every profile toggle lives
    # in one place; the implementing leaves (./desktop.nix, ./gaming.nix,
    # ./integrations.nix) are imported only when !isDarwin, so setting these
    # on darwin has no effect.
    desktop.enable = enableOn "the desktop profile (niri + DMS + GNOME fallback; Linux only)";

    desktop.loginManager = mkOption {
      type = types.enum ["gdm" "dms-greeter"];
      default = "dms-greeter";
      description = ''
        Login screen for the desktop profile.
        `gdm` — GNOME Display Manager.
        `dms-greeter` — DankMaterialShell greeter via greetd.
      '';
    };

    integrations = {
      enable = enableOn "the integrations meta-profile (AppImage + Flatpak; Linux only)";
      appimage.enable = enableOn "integrations.appimage (AppImage binfmt support)";
      flatpak.enable = enableOn "integrations.flatpak (flatpak daemon + Flathub remote)";
    };
  };

  config = let
    cfg = config.dotfiles.profiles;
    hostClass = host.hostClass or "workstation";
  in {
    assertions = [
      {
        assertion = !(hostClass == "server" && cfg.desktop.enable);
        message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.desktop; disable it in hosts/${hostKey}/profiles.nix.";
      }
      {
        assertion = !(hostClass == "server" && cfg.apps.enable);
        message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.apps; disable it in hosts/${hostKey}/profiles.nix.";
      }
      {
        assertion = !(hostClass == "server" && cfg.integrations.enable);
        message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.integrations; disable it in hosts/${hostKey}/profiles.nix.";
      }
      {
        assertion = !(hostClass == "server" && cfg.gaming.enable);
        message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.gaming; disable it in hosts/${hostKey}/profiles.nix.";
      }
      {
        assertion = !(hostClass == "server" && cfg.work.enable);
        message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.work; disable it in hosts/${hostKey}/profiles.nix.";
      }
    ];
  };
}
