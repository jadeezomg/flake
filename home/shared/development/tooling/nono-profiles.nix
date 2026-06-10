# Profile data lives in lib/nono-profiles.nix; installed under ~/.config/nono/profiles.
{
  lib,
  osConfig,
  pkgs,
  pkgs-small,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;

  profiles = (import ../../../../lib/nono-profiles.nix {inherit pkgs pkgs-small;}).profiles;

  mkProfileFile = name: data: {
    name = "nono/profiles/${name}.json";
    value = {
      text = builtins.toJSON data;
    };
  };
in
  lib.mkIf agentsEnabled {
    xdg.configFile = lib.mapAttrs' mkProfileFile profiles;
  }
