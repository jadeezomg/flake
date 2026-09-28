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
        enable = mkEnableOption "the apps profile: browsers (zen), terminals (ghostty, kitty), editors (helix), files (nautilus, localsend), comms (protonmail), notes, media (pear-desktop, obs). One flag; the category files under ./apps read it";
        # The one apps sub-flag that other modules still read (yazi openers,
        # the notes leaves). Folding it waits for the MIME move.
        notes.enable = mkEnableOption "apps.notes (obsidian, typora, whisp)";
      };

      devenv = {
        enable = mkEnableOption "the devenv profile, the headless SSH-safe dev core: tools (just, gh, lazygit, jujutsu), cloud (awscli2, awslogs), agents (agent CLIs, MCP config, the `data/agents/skills/` install), containers (podman CLI/TUI/compose), databases (rainfrog TUI). Only the languages below have their own flags";
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
        enable = mkEnableOption "the devgui profile, the GUI side of devenv with the same category names: agents (openwork cask on darwin), containers (podman-desktop), databases (tabularis), ides (vscode, zed)";
      };

      llm = {
        tools.enable = mkEnableOption "the LLM toolbox: llama.cpp CLI, huggingface-hub CLI, and the unsloth-studio podman user service (podman only on darwin)";

        llamaCppBackend = mkOption {
          type = types.nullOr (
            types.enum [
              "cpu"
              "vulkan"
              "cuda"
            ]
          );
          default = null;
          description = ''
            GPU backend for the llama-cpp package. `null` derives it from
            `dotfiles.hardware.gpu`: nvidia -> cuda, intel and amd -> vulkan,
            none -> cpu. `vulkan` comes from the public binary cache. `cuda`
            builds from source unless cache.nixos-cuda.org has it.
          '';
        };

        llamaCppPackage = mkOption {
          type = types.package;
          description = ''
            The llama-cpp package that `tools` install and `serve` run.
            ./llm sets it from the backend above. Override it to pin a build.
          '';
        };

        serve = {
          enable = mkEnableOption "the llama.cpp router server: one `llama-server --models-preset` unit that serves every model in `serve.models` on one port (Linux only)";

          host = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Bind address for llama-server.";
          };

          port = mkOption {
            type = types.port;
            default = 8000;
            description = "Listen port for the OpenAI-compatible API.";
          };

          threads = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "CPU threads for llama-server (`--threads`). `null` keeps the server default.";
          };

          modelsMax = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "How many models stay loaded at once (`--models-max`). `null` means all models in `serve.models`.";
          };

          gpuLayers = mkOption {
            type = types.int;
            default = 999;
            description = "Layers to offload to the GPU (`n-gpu-layers`) for every model. 999 means all.";
          };

          device = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Sets `LLAMA_ARG_DEVICE` to pick a GPU. `null` lets llama-server choose. List ids with `llama-server --list-devices`.";
          };

          stateDir = mkOption {
            type = types.str;
            default = "/var/lib/llama-cpp";
            description = "Home of the `llama` service user. Model files land in `<stateDir>/huggingface`.";
          };

          environmentFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Systemd `EnvironmentFile` for the unit, for example a sops template that carries `HF_TOKEN`.";
          };

          models = mkOption {
            default = { };
            description = ''
              Served models. The attribute name is the OpenAI model id and the
              INI section name. Keys render as long-form llama-server args
              without the leading `--`.
            '';
            type = types.attrsOf (
              types.submodule {
                options = {
                  hfRepo = mkOption {
                    type = types.str;
                    description = "Hugging Face GGUF repo, for example `unsloth/gemma-4-12B-it-qat-GGUF`.";
                  };
                  quant = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Quant tag appended as `<repo>:<quant>`. `null` lets llama.cpp pick.";
                  };
                  ctx = mkOption {
                    type = types.int;
                    description = "Total context pool in tokens (`ctx-size`). Split evenly across `slots`.";
                  };
                  slots = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                    description = "Parallel sequences (`parallel`). `null` keeps the server default of 1.";
                  };
                  kvType = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "KV cache type for K and V (`cache-type-k` and `cache-type-v`), for example `q8_0`. Needs `flashAttn = \"on\"`.";
                  };
                  embedding = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Serve this model on /v1/embeddings instead of chat.";
                  };
                  pooling = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Pooling for embedding models, for example `last` for Qwen3-arch embedders.";
                  };
                  mmprojAuto = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Load the repo's vision projector (`mmproj-auto`).";
                  };
                  flashAttn = mkOption {
                    type = types.nullOr (
                      types.enum [
                        "on"
                        "off"
                        "auto"
                      ]
                    );
                    default = null;
                    description = "`flash-attn` setting. `null` omits the key.";
                  };
                  settings = mkOption {
                    type = types.attrsOf (
                      types.oneOf [
                        types.bool
                        types.int
                        types.str
                      ]
                    );
                    default = { };
                    description = "Extra preset keys, for example sampling (`temp`, `top-p`) or `spec-type`. Write floats as strings, such as `temp = \"1.0\"`.";
                  };
                };
              }
            );
          };
        };
      };

      gaming.enable = mkEnableOption "the gaming profile (Steam stack — Linux only)";

      work.enable = mkEnableOption "the work profile (workato + postman + gws + AWS CLI; firefox/chrome via homebrew on darwin)";

      server.enable = mkEnableOption "the server profile (headless steering flag; mini enables it. Read by modules/nixos/{boot,networking}.nix)";

      # Linux-only profiles — options declared here so every profile toggle lives
      # in one place; the implementing leaves (./desktop, ./gaming.nix,
      # ./integrations.nix) are imported only when !isDarwin, so setting these
      # on darwin has no effect.
      desktop = {
        enable = enableOn "the desktop profile (niri + DMS or Noctalia + GNOME fallback; Linux only)";

        shell = mkOption {
          type = types.enum [
            "dms"
            "noctalia"
          ];
          default = "dms";
          description = ''
            Desktop shell for the niri session.
            `dms` — DankMaterialShell (default).
            `noctalia` — Noctalia v5 (flake TOML via HM `programs.noctalia.settings`).
          '';
        };

        loginManager = mkOption {
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
      };

      integrations.enable = enableOn "the integrations profile (AppImage binfmt support, flatpak daemon with the Flathub remote; Linux only)";
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
      guiProfiles = [
        "desktop.enable"
        "apps.enable"
        "integrations.enable"
        "gaming.enable"
        "work.enable"
        "fonts.full.enable"
        "theme.gui.enable"
        "devgui.enable"
      ];
    in
    {
      # A server-class host must not enable a GUI-facing profile. Each entry
      # is an option path under dotfiles.profiles.
      assertions = map (
        path:
        let
          enabled = lib.getAttrFromPath (lib.splitString "." path) cfg;
        in
        {
          assertion = !(hostClass == "server" && enabled);
          message = "Host `${hostKey}` has hostClass `server` but enables dotfiles.profiles.${path}; disable it in hosts/${hostKey}/profiles.nix.";
        }
      ) guiProfiles;
    };
}
