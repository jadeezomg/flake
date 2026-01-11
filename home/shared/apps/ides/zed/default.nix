{pkgs, ...}: {
  imports = [
    ./extensions.nix
    ./keybinds.nix
    ./languages.nix
    ./settings.nix
    ./theme.nix
  ];

  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
  };
}
