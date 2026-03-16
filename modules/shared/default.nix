{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./apps
    ./development
    ./environment
    ./fonts
    ./security
    ./shells
    ./utils
  ];
}
