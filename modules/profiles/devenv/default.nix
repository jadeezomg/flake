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
  # HM dev tooling without its own category (biome config, fnox secret hook,
  # gh CLI config, flake git hooks).
  hm = [
    ./biome.nix
    ./fnox.nix
    ./gh
    ./git-hooks.nix
  ];
  # Every language is on by default; hosts turn single ones off.
  extra.dotfiles.profiles.devenv.languages = lib.genAttrs langs (_: {
    enable = lib.mkDefault true;
  });
} args
