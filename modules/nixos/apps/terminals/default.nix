{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    alacritty
    ghostty
  ];
}
