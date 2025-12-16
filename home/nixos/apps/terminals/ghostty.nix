{pkgs, ...}: {
  imports = [
    ../../../shared/apps/terminals/ghostty.nix
  ];

  programs.ghostty = {
    package = pkgs.ghostty; # Linux package
    # settings = {
    #   linux-cgroup-memory-limit = 0;
    # };
  };
}
