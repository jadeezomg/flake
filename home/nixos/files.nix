{
  lib,
  osConfig,
  ...
}: {
  programs.zathura = lib.mkIf (osConfig.dotfiles.profiles.apps.files.enable or false) {
    enable = true;
  };
}
