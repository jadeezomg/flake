{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # NixOS-specific development tools
    gitui # Blazing fast terminal-ui for Git written in Rust (fails to build on Darwin)
  ];
}
