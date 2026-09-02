{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "nix"
  ];
  # The editor toolchain (`nixd` LSP + `nixfmt`) plus treefmt (via
  # nixfmt-tree) and lint-focused extras that a non-dev host (server)
  # wouldn't want.
  packages =
    pkgs: with pkgs; [
      nixd
      nixfmt
      nixfmt-tree
      deadnix
      statix
    ];
} args
