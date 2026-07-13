# Profile data lives in lib/nono-profiles.nix; installed under ~/.config/nono/profiles.
{
  dotfilesLib,
  lib,
  pkgs,
  pkgs-small,
  ...
}:
let
  profiles = (dotfilesLib.nonoProfiles { inherit pkgs pkgs-small; }).profiles;

  mkProfileFile = name: data: {
    name = "nono/profiles/${name}.json";
    value = {
      text = builtins.toJSON data;
    };
  };
in
{
  xdg.configFile = lib.mapAttrs' mkProfileFile profiles;
}
