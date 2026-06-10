{lib, ...}: let
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
  imports = map (l: ./. + "/${l}.nix") langs;

  # Instantiate each submodule so `languages.<lang>.enable` is always defined
  # (even when a host never opts into `devenv`). Default enable stays off —
  # devenv/default.nix mkDefaults them on when the meta flag is set.
  config.dotfiles.profiles.devenv.languages =
    lib.genAttrs langs (_: {});
}
