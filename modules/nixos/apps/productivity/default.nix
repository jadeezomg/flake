{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    pinta
  ];
}
