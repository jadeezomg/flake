{...}: {
  imports = [
    ./audio
    ./terminals
    ./files
  ];

  home.packages = with pkgs; [
    protonmail-desktop
  ];
}
