{...}: {
  imports = [
    ./brew-casks
    ./terminals
  ];

  home.packages = with pkgs; [
    nvtopPackages.apple
  ];
}
