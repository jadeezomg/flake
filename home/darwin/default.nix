{pkgs, ...}: {
  imports = [
    ./brew-casks
  ];

  home.packages = with pkgs; [
    nvtopPackages.apple
  ];
}
