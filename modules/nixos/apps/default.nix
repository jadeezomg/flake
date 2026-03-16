{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./browsers
  ];

  environment.systemPackages = with pkgs; [
    # Productivity
    pinta

    # Audio
    pear-desktop

    # Editors
    code-cursor
    zed-editor

    # Terminals
    alacritty
    ghostty
    kitty
  ];
}
