# devenv — the headless, SSH-safe dev core, separated by tool area.
# GUI dev tooling lives in ../devgui (mirrored category names); the LLM
# serving stack lives in ../llm.
{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv;

  # Keep in sync with ./languages/default.nix. Duplicated here on purpose:
  # mkDefault-ing from a single source would require an IFD-ish dance, and
  # the list rarely changes.
  langs = [
    "data"
    "docs"
    "general"
    "nix"
    "python"
    "rust"
    "shell"
    "web"
  ];
in
{
  imports = [
    ./tools.nix
    ./cloud.nix
    ./agents
    ./containers.nix
    ./databases.nix
    ./languages
  ];

  config = lib.mkIf cfg.enable {
    # HM dev tooling without its own category (biome config, fnox secret hook,
    # gh CLI config, flake git hooks, mise version manager).
    home-manager.sharedModules = [
      ./biome.nix
      ./fnox.nix
      ./gh
      ./git-hooks.nix
      ./mise.nix
    ];

    dotfiles.profiles.devenv = {
      tools.enable = lib.mkDefault true;
      cloud.enable = lib.mkDefault true;
      agents.enable = lib.mkDefault true;
      containers.enable = lib.mkDefault true;
      databases.enable = lib.mkDefault true;
      languages = lib.genAttrs langs (_: {
        enable = lib.mkDefault true;
      });
    };
  };
}
