{pkgs, ...}: {
  imports = [
    ./audio
    ./terminals
    ./files
  ];

  programs.mangohud.enable = true;

  home.packages = with pkgs; [
    protonmail-desktop
  ];
}
