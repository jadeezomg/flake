# Homepage: one start page for the services on mini and Unraid, at
# https://home.jadee.fyi (tailnet, and the LAN through Caddy's LAN bind).
#
# The full configuration is in Nix (services.homepage-dashboard). There is no
# web editor and no database. Each tile links to the service, shows a status
# dot from a loopback check, and, where Homepage has a widget, live numbers
# from the service API.
#
# API keys stay in sops. systemd gives them to Homepage as credentials, and
# Homepage reads each file where the configuration says
# {{HOMEPAGE_FILE_<NAME>}}. The keys never reach the browser: Homepage calls
# the APIs on the server side.
{
  config,
  dotfilesLib,
  host,
  lib,
  pkgs,
  pkgs-small,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) mkTsnetProxy;
  inherit (dotfilesLib.expiry { inherit lib; } "hosts/mini/services/homepage.nix") expireWhen;
  inherit (dotfilesLib.lanHosts) unraid;
  domain = "home.jadee.fyi";
  port = 8082;

  media = host.miniMediaHosting or false;
  local = port: path: "http://127.0.0.1:${toString port}${path}";

  # Credential name -> sops secret. The name must be one word: it becomes
  # part of an environment variable name.
  credentials = lib.optionalAttrs media {
    sonarr = "mini/media/sonarr/api-key";
    radarr = "mini/media/radarr/api-key";
    lidarr = "mini/media/lidarr/api-key";
    prowlarr = "mini/media/prowlarr/api-key";
    bazarr = "mini/media/bazarr/api-key";
    sabnzbd = "mini/media/sabnzbd/api-key";
    qbittorrent = "mini/media/qbittorrent/password";
    plex = "mini/media/plex/token";
    jellyfin = "mini/media/jellyfin/api-key";
    seerr = "mini/media/seerr/api-key";
  };
  fileVar = name: "HOMEPAGE_FILE_${lib.toUpper name}";
  secret = name: "{{${fileVar name}}}";

  tile =
    name:
    {
      href,
      icon,
      description,
      monitor,
      widget ? null,
    }:
    {
      ${name} = {
        inherit href icon description;
        siteMonitor = monitor;
      }
      // lib.optionalAttrs (widget != null) { inherit widget; };
    };

  # Radarr, Sonarr, Lidarr, Prowlarr and Bazarr: same tile, same widget shape.
  arr =
    name:
    {
      port,
      description,
      monitorPath ? "/ping",
    }:
    let
      type = lib.toLower name;
    in
    tile name {
      href = "https://${type}.jadee.fyi";
      icon = "${type}.svg";
      inherit description;
      monitor = local port monitorPath;
      widget = {
        inherit type;
        url = local port "";
        key = secret type;
      };
    };

  # sabnzbd and qbittorrent run in the VPN network namespace (see
  # media/proxy.nix), so they answer on the namespace address.
  sabnzbdUrl = "http://${config.nixflix.usenetClients.sabnzbd.connectionAddress}:8080";
  qbittorrent = config.nixflix.torrentClients.qbittorrent;
  qbittorrentUrl = "http://${qbittorrent.connectionAddress}:${toString qbittorrent.webuiPort}";

  groups = [
    {
      name = "Watch";
      columns = 3;
      tiles = lib.optionals media [
        (tile "Plex" {
          href = "https://plex.jadee.fyi";
          icon = "plex.svg";
          description = "Movies, series and music";
          monitor = local 32400 "/identity";
          widget = {
            type = "plex";
            url = local 32400 "";
            key = secret "plex";
          };
        })
        (tile "Jellyfin" {
          href = "https://jellyfin.jadee.fyi";
          icon = "jellyfin.svg";
          description = "Movies, series and music";
          monitor = local 8096 "/health";
          widget = {
            type = "jellyfin";
            url = local 8096 "";
            key = secret "jellyfin";
            # Jellyfin 12 (10.12) and later.
            version = 2;
            enableBlocks = true;
            enableNowPlaying = true;
            # The page has no login, so it must not pause other people's streams.
            enableMediaControl = false;
          };
        })
        (tile "Seerr" {
          href = "https://seerr.jadee.fyi";
          icon = "seerr.svg";
          description = "Requests";
          monitor = local 5055 "/api/v1/status";
          widget = {
            type = "seerr";
            url = local 5055 "";
            key = secret "seerr";
          };
        })
      ];
    }
    {
      name = "Library";
      columns = 4;
      tiles = lib.optionals media [
        (arr "Sonarr" {
          port = 8989;
          description = "Series";
        })
        (arr "Radarr" {
          port = 7878;
          description = "Movies";
        })
        (arr "Lidarr" {
          port = 8686;
          description = "Music";
        })
        (arr "Bazarr" {
          port = 6767;
          description = "Subtitles";
          monitorPath = "/";
        })
      ];
    }
    {
      name = "Downloads";
      columns = 4;
      tiles =
        lib.optionals media [
          (arr "Prowlarr" {
            port = 9696;
            description = "Indexers";
          })
          (tile "SABnzbd" {
            href = "https://sabnzbd.jadee.fyi";
            icon = "sabnzbd.svg";
            description = "Usenet";
            monitor = sabnzbdUrl;
            widget = {
              type = "sabnzbd";
              url = sabnzbdUrl;
              key = secret "sabnzbd";
            };
          })
          (tile "qBittorrent" {
            href = "https://qbittorrent.jadee.fyi";
            icon = "qbittorrent.svg";
            description = "Torrents";
            monitor = qbittorrentUrl;
            widget = {
              type = "qbittorrent";
              url = qbittorrentUrl;
              username = qbittorrent.serverConfig.Preferences.WebUI.Username;
              password = secret "qbittorrent";
            };
          })
        ]
        ++ [
          (tile "JDownloader" {
            href = "http://${unraid.tailnet}:7807";
            icon = "jdownloader.svg";
            description = "Direct downloads (Unraid)";
            monitor = "http://${unraid.lan}:7807";
          })
        ];
    }
    {
      name = "Apps";
      columns = 4;
      tiles =
        lib.optional (host.miniImmich or false) (
          tile "Immich" {
            href = "https://immich.jadee.fyi";
            icon = "immich.svg";
            description = "Photos and videos";
            monitor = local config.services.immich.port "/api/server/ping";
          }
        )
        ++ lib.optional (host.miniLlmHosting or false) (
          tile "Open WebUI" {
            href = "https://chat.jadee.fyi";
            icon = "open-webui.svg";
            description = "Chat with the local LLM";
            monitor = local config.services.open-webui.port "/health";
          }
        )
        ++ [
          (tile "Hermes" {
            href = "https://hermes.jadee.fyi/sessions";
            icon = "mdi-robot-outline";
            description = "Agent dashboard";
            # The dashboard port from hermes-dashboard.nix.
            monitor = local 9119 "/";
          })
          (tile "Cinny" {
            href = "https://cinny.jadee.fyi";
            icon = "cinny.svg";
            description = "Matrix chat";
            monitor = local (lib.head config.services.matrix-continuwuity.settings.global.port) "/_matrix/client/versions";
          })
        ];
    }
    {
      name = "System";
      columns = 4;
      tiles = [
        (tile "Unraid" {
          href = "http://${unraid.tailnet}";
          icon = "unraid.svg";
          description = "NAS: array, shares and containers";
          monitor = "http://${unraid.lan}";
        })
      ]
      ++ lib.optional (host.miniMonitoring or false) (
        tile "Beszel" {
          href = "https://beszel.jadee.fyi";
          icon = "beszel.svg";
          description = "System metrics for mini and Unraid";
          monitor = local config.services.beszel.hub.port "/api/health";
        }
      )
      ++ lib.optional (host.miniTracing or false) (
        tile "Grafana" {
          href = "https://grafana.jadee.fyi";
          icon = "grafana.svg";
          description = "Traces of Nix builds and services";
          monitor = local config.services.grafana.settings.server.http_port "/api/health";
        }
      )
      ++ [
        (tile "ntfy" {
          href = "https://ntfy.jadee.fyi";
          icon = "ntfy.svg";
          description = "Push notifications";
          monitor = "http://${config.services.ntfy-sh.settings.listen-http}/v1/health";
        })
      ];
    }
  ];
  shown = lib.filter (group: group.tiles != [ ]) groups;
in
{
  services.homepage-dashboard = {
    enable = true;
    # Our nixos-unstable lock has 2.4.0. nixos-unstable-small already has
    # 2.6.0 in the binary cache. 2.6.0 fixes GHSA-qxcr-4rv3-v23r and keeps "$"
    # in file secrets.
    package = expireWhen {
      fixed = lib.versionAtLeast pkgs.homepage-dashboard.version "2.6.0";
      reason = "nixos-unstable now ships homepage-dashboard >= 2.6.0.";
      fallback = pkgs.homepage-dashboard;
    } pkgs-small.homepage-dashboard;
    listenPort = port;
    allowedHosts = domain;

    settings = {
      title = "jadee";
      description = "Services on mini and Unraid";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";
      statusStyle = "dot";
      hideVersion = true;
      # Nix sets the version. A notice about a newer release only adds noise.
      disableUpdateCheck = true;
      # A list, not an attribute set: Homepage shows the groups in this order.
      layout = map (group: {
        ${group.name} = {
          style = "row";
          inherit (group) columns;
        };
      }) shown;
    };

    services = map (group: { ${group.name} = group.tiles; }) shown;

    widgets = [
      {
        resources = {
          label = "mini";
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        datetime = {
          text_size = "md";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hourCycle = "h23";
          };
        };
      }
    ];
  };

  systemd.services.homepage-dashboard = {
    environment = {
      # Loopback only. Caddy is the front door, as for every other service.
      HOSTNAME = "127.0.0.1";
    }
    // lib.mapAttrs' (
      name: _: lib.nameValuePair (fileVar name) "/run/credentials/homepage-dashboard.service/${name}"
    ) credentials;
    serviceConfig.LoadCredential = lib.mapAttrsToList (
      name: path: "${name}:${config.sops.secrets.${path}.path}"
    ) credentials;
  };

  # Restart Homepage when a key changes.
  sops.secrets = lib.mapAttrs' (
    _: path: lib.nameValuePair path { restartUnits = [ "homepage-dashboard.service" ]; }
  ) credentials;

  services.caddy.virtualHosts = mkTsnetProxy { inherit domain port; };
}
