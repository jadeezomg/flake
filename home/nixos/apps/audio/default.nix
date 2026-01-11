{pkgs, ...}: {
  home.packages = with pkgs; [
    pear-desktop
  ];

  # Create desktop entry for pear-desktop so it appears in DMS launcher
  xdg.desktopEntries."pear-desktop" = {
    name = "Pear Desktop";
    genericName = "YouTube Music Desktop";
    exec = "pear-desktop";
    icon = "pear-desktop";
    terminal = false;
    categories = ["Audio" "Music" "Player"];
    comment = "YouTube Music Desktop Client";
  };
}
