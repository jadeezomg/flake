# mise — polyglot tool/runtime version manager and task runner.
#
# mise is inside the nix closure on both platforms, so home-manager generates
# the shell activation snippets at build time. nushell gets a store path it can
# `use`, which is why the writable-cache dance the Homebrew mise needed on
# Darwin is gone.
_: {
  programs.mise.enable = true;
}
