{pkgs, ...}: {
  imports = [
    ../../shared/apps/terminals/ghostty.nix
  ];

  programs.ghostty = {
    package = pkgs.ghostty; # Linux package
    settings = {
      # Performance (Linux-specific)
      linux-cgroup-memory-limit = 0;
    };
  };
}
