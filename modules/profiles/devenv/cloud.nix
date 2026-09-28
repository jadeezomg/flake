{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  packages =
    pkgs: with pkgs; [
      awscli2
      awslogs
      flarectl
    ];
} args
