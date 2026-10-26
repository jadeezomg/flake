# Unpackerr: extracts torrent downloads that arrive as RAR archives, so
# Radarr/Sonarr/Lidarr can import them. It asks each app for its queue and
# extracts finished torrents in place; the app imports the result and
# Unpackerr deletes the extracted copy after the import. SABnzbd extracts
# usenet downloads itself, so only torrents are handled here.
{ config, lib, ... }:
let
  inherit (import ./nixflix/common.nix) mountDeps;

  apps = {
    radarr = 7878;
    sonarr = 8989;
    lidarr = 8686;
  };
  # `filepath:` makes Unpackerr read the key from the credential file.
  instance = app: port: [
    {
      url = "http://127.0.0.1:${toString port}";
      api_key = "filepath:/run/credentials/unpackerr.service/${app}-api-key";
      paths = [ "/data/torrents" ];
      protocols = "torrent";
    }
  ];
in
{
  services.unpackerr = {
    enable = true;
    # The download folders belong to unraid:users with mode 0775.
    group = "users";
    settings = {
      parallel = 1;
      start_delay = "1m";
      retry_delay = "5m";
      file_mode = "0664";
      dir_mode = "0775";
    }
    // lib.mapAttrs instance apps;
  };

  systemd.services.unpackerr = {
    after = mountDeps;
    requires = mountDeps;
    serviceConfig = {
      LoadCredential = lib.mapAttrsToList (
        app: _: "${app}-api-key:${config.sops.secrets."mini/media/${app}/api-key".path}"
      ) apps;
      UMask = "0002";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      # One entry for /data, as for the Arr apps (ADR-0006). An entry for
      # /data/torrents is a bind mount that the kernel detaches when Unraid
      # gives a parent folder a new inode number. Unpackerr then sees a
      # read-only /data (docs/hosts/mini.md § Media stack).
      ReadWritePaths = [ "/data" ];
    };
  };
}
