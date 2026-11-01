# Unraid's `data` and `Stuff` shares over NFS, for Nautilus on the desktop hosts.
# The mounts use the tailnet name, so the laptop also reaches them away from
# home. Unraid exports both shares to these hosts' tailnet addresses with
# all_squash, so every write lands as nobody:users (99:100), like mini's.
# A share mounts on first access and unmounts after 10 idle minutes. `soft`
# lets a file manager get an error instead of hanging when Unraid is offline.
# Nautilus lists an idle automount nowhere, so both shares are GTK bookmarks;
# opening one triggers the mount.
{
  config,
  dotfilesLib,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  inherit (dotfilesLib.lanHosts) unraid;
  share = name: {
    device = "${unraid.tailnet}:${unraid.shareRoot}/${name}";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
      "x-systemd.mount-timeout=15s"
      "_netdev"
      "soft"
      "timeo=100"
      "retrans=3"
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/mnt/unraid/data" = share "data";
      "/mnt/unraid/Stuff" = share "Stuff";
    };

    # Nautilus writes this file itself, so append instead of managing it.
    home-manager.sharedModules = [
      (
        { lib, ... }:
        {
          home.activation.unraidBookmarks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            f="$HOME/.config/gtk-3.0/bookmarks"
            mkdir -p "$(dirname "$f")"
            touch "$f"
            for b in "file:///mnt/unraid/data Unraid data" "file:///mnt/unraid/Stuff Unraid Stuff"; do
              grep -qxF "$b" "$f" || printf '%s\n' "$b" >>"$f"
            done
          '';
        }
      )
    ];
  };
}
