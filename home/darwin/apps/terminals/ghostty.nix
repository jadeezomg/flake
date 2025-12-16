{pkgs, ...}: {
  imports = [
    ../../shared/apps/terminals/ghostty.nix
  ];

  programs.ghostty = {
    package = pkgs.ghostty-bin; # macOS package
  };
}
