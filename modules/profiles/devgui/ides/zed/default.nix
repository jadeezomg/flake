{ pkgs, ... }: {
  imports = [
    ./extensions.nix
    ./keybinds.nix
    ./languages.nix
    ./mcp-cleanup.nix
    ./settings.nix
    ./tasks.nix
    ./theme.nix
  ];

  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
  };
}
