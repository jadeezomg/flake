{
  dotfilesLib,
  isDarwin ? false,
  lib,
  ...
}@args:
dotfilesLib.mkProfile {
  path = [ "work" ];
  # ./darwin holds the homebrew side (+ cask app HM configs); the
  # `homebrew.*` namespace only exists on darwin, hence the import gate.
  imports = lib.optionals isDarwin [ ./darwin ];

  packages =
    pkgs: with pkgs; [
      postman
      gws
      workato-platform-cli
    ];
} args
