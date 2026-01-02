{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./browsers
    ./terminals
  ];
}
