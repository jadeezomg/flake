# devenv — the headless, SSH-safe dev core, separated by tool area.
# GUI dev tooling lives in ../devgui (mirrored category names); the LLM
# serving stack lives in ../llm.
{
  config,
  lib,
  ...
}: let
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
    "ruby"
    "rust"
    "shell"
    "swift"
    "web"
  ];
in {
  imports = [
    ./tools.nix
    ./cloud.nix
    ./agents
    ./containers.nix
    ./databases.nix
    ./languages
  ];

  # Convenience: enabling devenv.enable turns on every sub-profile that
  # ships with the workstation today. Hosts override individual flags
  # (e.g. `devenv.languages.swift.enable = false;`) without losing the
  # meta-flag.
  config = lib.mkIf cfg.enable {
    # HM dev tooling without its own category (biome config).
    home-manager.sharedModules = [./biome.nix];

    dotfiles.profiles.devenv = {
      tools.enable = lib.mkDefault true;
      cloud.enable = lib.mkDefault true;
      agents.enable = lib.mkDefault true;
      containers.enable = lib.mkDefault true;
      databases.enable = lib.mkDefault true;
      languages = lib.genAttrs langs (_: {enable = lib.mkDefault true;});
    };
  };
}
