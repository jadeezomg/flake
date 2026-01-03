{pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    # IDEs
    zed-editor
    code-cursor
  ];
}
