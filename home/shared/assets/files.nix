{
  config,
  ...
}: let
  flakeRoot = "${config.home.homeDirectory}/.dotfiles/flake";
  assetsDir = "${flakeRoot}/home/shared/assets";
in {
  home.file = {
    "Pictures/Images" = {
      source = config.lib.file.mkOutOfStoreSymlink "${assetsDir}/images";
      force = true;
    };

    "Pictures/Wallpapers" = {
      source = config.lib.file.mkOutOfStoreSymlink "${assetsDir}/wallpapers";
      force = true;
    };
  };
}
