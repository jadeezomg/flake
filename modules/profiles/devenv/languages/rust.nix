{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "rust"
  ];
  packages =
    pkgs: with pkgs; [
      rustup
      bacon
      clippy
      cargo
      cargo-generate
      cargo-nextest
      cargo-seek
      cargo-info
      rusty-man
    ];
} args
