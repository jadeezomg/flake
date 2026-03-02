{pkgs, ...}: {
  imports = [
    ../../../shared/apps/terminals/ghostty.nix
  ];

  programs.ghostty = {
    package = pkgs.ghostty; # Linux package
    systemd.enable = true; # Only enable systemd integration on Linux
    # settings = {
    #   linux-cgroup-memory-limit = 0;
    # };
  };
}
