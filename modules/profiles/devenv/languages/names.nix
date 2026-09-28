# The language list, read from this folder. Every `<name>.nix` beside this
# file is one language sub-profile, so adding a file adds the language.
# `builtins.readDir` on a flake path is a plain eval, not an IFD.
{ lib }:
let
  isLang =
    name: type:
    type == "regular"
    && lib.hasSuffix ".nix" name
    && !(lib.elem name [
      "default.nix"
      "names.nix"
    ]);
in
map (lib.removeSuffix ".nix") (lib.attrNames (lib.filterAttrs isLang (builtins.readDir ./.)))
