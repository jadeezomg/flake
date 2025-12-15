{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    pkgs.ghostty-bin
  ];
}
