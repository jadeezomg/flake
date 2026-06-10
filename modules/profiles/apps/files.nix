{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.files;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optionals (!isDarwin) (with pkgs; [
      nautilus # GNOME file manager
      ventoy # create bootable USB drives
    ]);
  };
}
