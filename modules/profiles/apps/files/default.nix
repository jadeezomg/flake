{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.files;
in
{
  config = lib.mkIf cfg.enable {
    # HM half (zathura) was Linux-only under home/nixos — keep that scope.
    home-manager.sharedModules = lib.optionals (!isDarwin) [ ./zathura.nix ];

    environment.systemPackages = lib.optionals (!isDarwin) (
      with pkgs;
      [
        file-roller # GNOME archive manager for zip/rar/7z and other archives.
        nautilus # GNOME file manager
        ventoy # create bootable USB drives
      ]
    );
  };
}
