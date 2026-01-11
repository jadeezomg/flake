{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./audio
    ./browsers
    ./terminals
  ];
}
