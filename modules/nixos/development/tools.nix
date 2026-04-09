{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # NixOS-specific development tools
  ];
}
