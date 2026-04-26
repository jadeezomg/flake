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
    ./llm
    ./containers.nix
    ./databases.nix
    ./languages
  ];

  # Convenience: enabling devenv.enable turns on every sub-profile that
  # ships with the workstation today. A future "server" host overrides
  # individual flags (e.g. `apps.enable = false; devenv.containers.enable
  # = false;`) without losing the meta-flag.
  config = lib.mkIf cfg.enable {
    dotfiles.profiles.devenv = {
      tools.enable = lib.mkDefault true;
      cloud.enable = lib.mkDefault true;
      containers.enable = lib.mkDefault true;
      databases.enable = lib.mkDefault true;
      llm = {
        agents = {
          enable = lib.mkDefault true;
          thirdPartySkills.enable = lib.mkDefault true;
        };
        hosting.enable = lib.mkDefault true;
      };
      languages = lib.genAttrs langs (_: {enable = lib.mkDefault true;});
    };
  };
}
