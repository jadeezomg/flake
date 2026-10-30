# GUI counterpart of devenv.agents (the agent CLIs stay headless-side).
# ./darwin.nix holds the Zed's Delta cask; the `homebrew.*` namespace only exists
# on darwin, hence the import gate.
{
  isDarwin ? false,
  lib,
  ...
}:
{
  imports = lib.optionals isDarwin [ ./darwin.nix ];
}
