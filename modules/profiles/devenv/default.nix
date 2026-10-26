# devenv — the headless, SSH-safe dev core, separated by tool area.
# GUI dev tooling lives in ../devgui (mirrored category names); the LLM
# serving stack lives in ../llm.
{
  dotfilesLib,
  lib,
  ...
}@args:
let
  langs = import ./languages/names.nix { inherit lib; };
in
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  imports = [
    ./tools.nix
    ./cloud.nix
    ./agents
    ./containers.nix
    ./databases.nix
    ./languages
  ];
  # HM dev tooling without its own category (biome config, gh CLI config,
  # lazygit config, flake git hooks). fnox is not here: each repo pins it in
  # its mise.toml, and no shell hook loads secrets. A command that needs a
  # secret runs through `fnox exec`.
  hm = [
    ./biome.nix
    ./gh
    ./lazygit
    ./git-hooks.nix
  ];
  # Every language is on by default; hosts turn single ones off.
  extra.dotfiles.profiles.devenv.languages = lib.genAttrs langs (_: {
    enable = lib.mkDefault true;
  });
} args
