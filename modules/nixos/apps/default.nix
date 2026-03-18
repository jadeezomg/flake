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
    gradia # screeshot editor
    pinta # image editor

    # Audio
    pear-desktop # ytm player

    # Editors
    code-cursor
    zed-editor

    # Terminals
    alacritty
    ghostty
    kitty
  ];
}
