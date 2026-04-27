# direnv's upstream test suite (esp. zsh) can hang or run far too long under
# the macOS Nix sandbox, blocking the whole system/home closure. Skipping check
# only on Darwin; Linux nixpkgs/Hydra paths keep running tests.
{system}: _final: prev: let
  isDarwin = builtins.match ".*-darwin" system != null;
in
  if !isDarwin
  then {}
  else {
    direnv = prev.direnv.overrideAttrs (_old: {doCheck = false;});
  }
