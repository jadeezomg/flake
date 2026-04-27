{lib, ...}: {
  imports = [
    ./minimal.nix
    ./essentials.nix
    ./apps
    ./devenv
    ./work.nix
    ./server.nix
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
        agents.enable = mkEnableOption "devenv.llm.agents (opencode, claude-code, context7, kagi-ken, ...) and the flake `agent-skills/` install";
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
          `modules/shared/profiles/devenv/languages/<name>.nix` wires the
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
    # in one place; the implementing modules (modules/nixos/profiles/{desktop,
    # integrations}.nix) are only evaluated on NixOS, so setting these on
    # darwin has no effect.
    desktop.enable = enableOn "the desktop profile (niri + DMS + GNOME fallback; Linux only)";

    integrations = {
      enable = enableOn "the integrations meta-profile (AppImage + Flatpak; Linux only)";
      appimage.enable = enableOn "integrations.appimage (AppImage binfmt support)";
      flatpak.enable = enableOn "integrations.flatpak (flatpak daemon + Flathub remote)";
    };
  };
}
