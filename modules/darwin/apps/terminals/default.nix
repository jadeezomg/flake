{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./ghostty.nix
    ./wezterm.nix
  ];
}
