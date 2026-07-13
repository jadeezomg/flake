# Darwin user baseline (was home/darwin/default.nix).
{ pkgs, ... }: {
  # Home-manager defaults xdg.enable to false on Darwin, which routes program
  # configs to ~/Library/Application Support/. Several CLI tools (e.g. navi)
  # only read the XDG path, so enable it and keep config locations in sync
  # with the Linux hosts.
  xdg.enable = true;

  home.packages = with pkgs; [
    nvtopPackages.apple
  ];
}
