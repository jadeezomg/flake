{
  config,
  host ? { },
  hostKey ? "unknown",
  isDarwin ? false,
  lib,
  ...
}:
{
  # Linux-only leaves are gated at import level (not mkIf) because their
  # option namespaces (programs.steam, services.flatpak, …) don't exist on
  # darwin. `isDarwin` comes from specialArgs, so this is legal in `imports`.
  imports = [
    ./minimal
    ./essentials
    ./fonts
    ./theme
    ./apps
    ./devenv
    ./devgui
    ./llm
    ./work
    ./server.nix
  ]
  ++ lib.optionals (!isDarwin) [
    ./desktop
    ./gaming.nix
    ./integrations.nix
    ./hardware
  ];

  options.dotfiles.profiles =
    let
      inherit (lib) mkEnableOption mkOption types;

      enableOn =
        description:
        mkEnableOption description
        // {
          default = true;
        };
    in
    {
      minimal.enable = enableOn "the minimal profile (system core + sandbox-safe shells + daily-driver CLIs)";

      essentials = {
        enable = enableOn "the essentials profile (Starship prompt, HM widgets, system env, Nix workstation tooling)";
      };

      fonts = {
        enable = enableOn "the fonts baseline (Stylix-referenced: Iosevka NF, Iosevka Etoile, Inter, Noto emoji)";
        full.enable = enableOn "the full font catalogue (workstations; the server keeps the baseline only)";
      };

      theme = {
        enable = enableOn "the theme baseline (Stylix + Birds-of-Paradise base16; CLI/shell theming everywhere)";
        gui.enable = enableOn "the theme GUI payload (wallpaper, cursor, opacity, GTK/Qt, Pictures symlinks; the server keeps CLI theming only)";
      };

      apps = {
        enable = mkEnableOption "the apps meta-profile";
        browsers.enable = mkEnableOption "apps.browsers (zen-browser; firefox/chrome live in work)";
        terminals.enable = mkEnableOption "apps.terminals (ghostty, kitty)";
        editors.enable = mkEnableOption "apps.editors (helix; cursor/zed live in devgui.ides)";
        files.enable = mkEnableOption "apps.files (nautilus/filezilla in nixos modules)";
        comms.enable = mkEnableOption "apps.comms (protonmail-desktop, etc.)";
        notes.enable = mkEnableOption "apps.notes (obsidian, typora)";
        media.enable = mkEnableOption "apps.media (pear-desktop, future media players)";
      };

      devenv = {
        enable = mkEnableOption "the devenv meta-profile — headless, SSH-safe dev core";
        tools.enable = mkEnableOption "devenv.tools (git, just, gh, lazygit, delta, jujutsu, etc.)";
        cloud.enable = mkEnableOption "devenv.cloud (awscli2, awslogs)";
        agents.enable = mkEnableOption "devenv.agents (agent CLIs: claude-code, codex, herdr, ctx7, context7-mcp, kagi, … plus MCP config and the flake `data/agents/skills/` install)";
        containers.enable = mkEnableOption "devenv.containers (podman CLI/TUI/compose; GUI lives in devgui.containers)";
        databases.enable = mkEnableOption "devenv.databases (rainfrog TUI)";
        languages = mkOption {
          type = types.attrsOf (
            types.submodule {
              options.enable = mkEnableOption "this language sub-profile";
            }
          );
          default = { };
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

      devgui = {
        enable = mkEnableOption "the devgui meta-profile — GUI dev tooling; mirrors devenv's category names";
        containers.enable = mkEnableOption "devgui.containers (podman-desktop)";
        ides.enable = mkEnableOption "devgui.ides (cursor, zed — system packages on NixOS + HM configs)";
      };

      llm = {
        enable = mkEnableOption "the LLM serving stack (llama.cpp server + unsloth-studio podman service + huggingface-cli); mini serves via its own llama-cpp host modules instead";
        llamaCppBackend = mkOption {
          type = types.enum [
            "vulkan"
            "cuda"
          ];
          default = "vulkan";
          description = ''
            GPU backend for the llama-cpp package. `vulkan` works on any Mesa
            GPU and comes from the binary cache; `cuda` (NVIDIA) builds from
            source locally — only worth it on the desktop.
          '';
        };
        colibri.enable = mkEnableOption ''
          [colibrì](https://github.com/JustVugg/colibri) CLI (`coli`) for GLM-5.2 MoE
          inference. Set `COLI_MODEL` to an int4 model directory on fast storage
          (~372 GB); the flake only ships the engine.
        '';
      };

      gaming.enable = mkEnableOption "the gaming profile (Steam stack — Linux only)";

      work.enable = mkEnableOption "the work profile (workato + postman + gws + AWS CLI; firefox/chrome via homebrew on darwin)";

      server.enable = mkEnableOption "the server profile (parked: postgresql, redis — no host imports yet, see Q9)";

      # Linux-only profiles — options declared here so every profile toggle lives
      # in one place; the implementing leaves (./desktop, ./gaming.nix,
      # ./integrations.nix) are imported only when !isDarwin, so setting these
      # on darwin has no effect.
      desktop.enable = enableOn "the desktop profile (niri + DMS + GNOME fallback; Linux only)";

      desktop.loginManager = mkOption {
        type = types.enum [
          "gdm"
          "dms-greeter"
        ];
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

  # Hardware traits — what a machine IS (radio, GPU vendor, CPU family), as
  # opposed to profiles (what it's FOR). Implemented in ./hardware (Linux
  # only); set per host in hosts/<name>/profiles.nix.
  options.dotfiles.hardware =
    let
      inherit (lib) mkEnableOption mkOption types;
    in
    {
      wireless.enable = mkEnableOption "wireless radios — wifi tooling + bluetooth/blueman (combo trait; radio modules almost always carry both)";
      gpu = mkOption {
        type = types.enum [
          "nvidia"
          "amd"
          "intel"
          "none"
        ];
        default = "none";
        description = "Primary GPU vendor — selects driver + tooling leaf (./hardware/gpu-*.nix).";
      };
      cpu = {
        zen4.enable = mkEnableOption "Zen4 CPU (cachyos zen4-tuned kernel on non-server hosts)";
        x3d.enable = mkEnableOption "AMD X3D CPU (gamemode core-parking hints in the gaming profile)";
      };
    };

  config =
    let
      cfg = config.dotfiles.profiles;
      hostClass = host.hostClass or "workstation";
    in
    {
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
        {
          assertion = !(hostClass == "server" && cfg.fonts.full.enable);
          message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.fonts.full; disable it in hosts/${hostKey}/profiles.nix.";
        }
        {
          assertion = !(hostClass == "server" && cfg.theme.gui.enable);
          message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.theme.gui; disable it in hosts/${hostKey}/profiles.nix.";
        }
        {
          assertion = !(hostClass == "server" && cfg.devgui.enable);
          message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.devgui; disable it in hosts/${hostKey}/profiles.nix.";
        }
      ];
    };
}
