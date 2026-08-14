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
  config = lib.mkIf cfg.enable (
    lib.mkMerge (
      [
        {
          environment.systemPackages = lib.optionals (!isDarwin) (
            with pkgs;
            [
              file-roller # GNOME archive manager for zip/rar/7z and other archives.
              nautilus # GNOME file manager
              ventoy # create bootable USB drives
              localsend # file sharing
            ]
          );
        }
      ]
      # `networking.firewall` only exists on NixOS. `lib.mkIf` would still
      # register the definition and fail on Darwin with "option does not
      # exist", so the whole attrset must drop out of the merge list instead.
      ++ lib.optionals (!isDarwin) [
        {
          # LocalSend uses one port for both roles: UDP 53317 carries the
          # multicast announcements (224.0.0.167) that make peers show up, TCP
          # 53317 carries the HTTP transfer. Without the UDP rule the peer list
          # stays empty even though both devices are on the same LAN.
          networking.firewall = {
            allowedTCPPorts = [ 53317 ];
            allowedUDPPorts = [ 53317 ];
          };
        }
      ]
    )
  );
}
