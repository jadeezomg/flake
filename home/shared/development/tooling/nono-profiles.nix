# Installs nono profiles to ~/.config/nono/profiles/<name>.json so they
# resolve by name from `nono run --profile <name>`. Profile data lives in
# lib/nono-profiles.nix (single source of truth, also consumed by the
# devShells in parts/shells.nix).
{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;

  profiles = (import ../../../../lib/nono-profiles.nix {inherit pkgs;}).profiles;

  mkProfileFile = name: data: {
    name = "nono/profiles/${name}.json";
    value = {text = builtins.toJSON data;};
  };
in
  lib.mkIf agentsEnabled {
    xdg.configFile = lib.mapAttrs' mkProfileFile profiles;
  }
