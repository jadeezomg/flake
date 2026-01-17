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

    # Terminals
    alacritty
    ghostty
  ];
}
