{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "apps" ];
  hm = [ ./helix.nix ];
} args
