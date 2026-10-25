# Homepage: one start page for the services on mini and Unraid, at
# https://home.jadee.fyi (tailnet, and the LAN through Caddy's LAN bind).
#
# The full configuration is in Nix (services.homepage-dashboard). There is no
# web editor and no database. Each tile links to the service, shows a status
# dot from a loopback check, and, where Homepage has a widget, live numbers
# from the service API. ./theme.nix holds the palette and the wallpapers.
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
  inherit (import ../lib.nix { inherit lib; }) mkTsnetProxy;
  inherit (dotfilesLib.expiry { inherit lib; } "hosts/mini/services/homepage/default.nix") expireWhen;
  inherit (dotfilesLib.lanHosts) router unraid;
  domain = "home.jadee.fyi";
  port = 8082;

  theme = import ./theme.nix {
    inherit lib pkgs;
    palette = dotfilesLib.paletteVariants.${config.dotfiles.profiles.theme.variant};
  };

  media = host.miniMediaHosting or false;
  immich = host.miniImmich or false;
  beszel = host.miniMonitoring or false;
  local = port: path: "http://127.0.0.1:${toString port}${path}";

  # Credential name -> sops secret. The name must be one word: it becomes
  # part of an environment variable name.
  credentials = {
    unraid = "mini/homepage/unraid-api-key";
    ntfy = "mini/ntfy/homepage-token";
  }
  // lib.optionalAttrs media {
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
  }
  // lib.optionalAttrs immich { immich = "mini/homepage/immich-api-key"; }
  // lib.optionalAttrs beszel { beszel = "mini/homepage/beszel-password"; };
  fileVar = name: "HOMEPAGE_FILE_${lib.toUpper name}";
  secret = name: "{{${fileVar name}}}";

  tile =
    name:
    {
      href ? null,
      icon,
      description,
      monitor,
      widget ? null,
    }:
    {
      ${name} = {
        inherit icon description;
        siteMonitor = monitor;
      }
      // lib.optionalAttrs (href != null) { inherit href; }
      // lib.optionalAttrs (widget != null) { inherit widget; };
    };

  # Radarr, Sonarr, Lidarr, Prowlarr and Bazarr: same tile, same widget shape.
  arr =
    name:
    {
      port,
      description,
      monitorPath ? "/ping",
      widgetExtra ? { },
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
      }
      // widgetExtra;
    };

  # The calendar reads its events through these tiles' widgets.
  library = "Library";
  calendarSources = [
    "Sonarr"
    "Radarr"
    "Lidarr"
  ];

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
      name = library;
      columns = 4;
      tiles = lib.optionals media [
        (arr "Sonarr" {
          port = 8989;
          description = "Series";
          widgetExtra.enableQueue = true;
        })
        (arr "Radarr" {
          port = 7878;
          description = "Movies";
          widgetExtra.enableQueue = true;
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
      name = "Coming up";
      columns = 1;
      tiles = lib.optionals media [
        {
          Calendar.widget = {
            type = "calendar";
            view = "agenda";
            maxEvents = 10;
            showTime = true;
            integrations = map (name: {
              type = lib.toLower name;
              service_group = library;
              service_name = name;
              baseUrl = "https://${lib.toLower name}.jadee.fyi";
            }) calendarSources;
          };
        }
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
        lib.optional immich (
          tile "Immich" {
            href = "https://immich.jadee.fyi";
            icon = "immich.svg";
            description = "Photos and videos";
            monitor = local config.services.immich.port "/api/server/ping";
            widget = {
              type = "immich";
              url = local config.services.immich.port "";
              key = secret "immich";
              # Immich 1.118 and later.
              version = 2;
            };
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
          widget = {
            type = "unraid";
            url = "http://${unraid.lan}";
            key = secret "unraid";
            # The SSD pool that holds downloads (see media/nixflix/downloaders.nix).
            pool1 = "array_cache";
            fields = [
              "cpu"
              "memoryPercent"
              "arrayFree"
              "pool1FreeSpace"
            ];
          };
        })
      ]
      ++ lib.optional beszel (
        tile "Beszel" {
          href = "https://beszel.jadee.fyi";
          icon = "beszel.svg";
          description = "System metrics for mini and Unraid";
          monitor = local config.services.beszel.hub.port "/api/health";
          widget = {
            type = "beszel";
            url = local config.services.beszel.hub.port "";
            # A read-only Beszel user (docs/hosts/mini.md § Homepage).
            username = "homepage@jadee.fyi";
            password = secret "beszel";
            # Beszel 0.9 and later.
            version = 2;
          };
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
          description = "Last alert from mini";
          monitor = "http://${config.services.ntfy-sh.settings.listen-http}/v1/health";
          widget = {
            type = "ntfy";
            url = "http://${config.services.ntfy-sh.settings.listen-http}";
            topic = "system";
            key = secret "ntfy";
          };
        })
      ];
    }
    {
      name = "Network";
      columns = 2;
      tiles = [
        (tile "FRITZ!Box" {
          href = "http://${router.lan}";
          icon = "fritzbox.svg";
          description = "Internet connection";
          monitor = "http://${router.lan}";
          # UPnP status needs no login (docs/hosts/mini.md § Homepage).
          widget = {
            type = "fritzbox";
            url = "http://${router.lan}";
            fields = [
              "connectionStatus"
              "uptime"
              "down"
              "up"
            ];
          };
        })
        (tile "Caddy" {
          icon = "caddy.svg";
          description = "Reverse proxy for every *.jadee.fyi name";
          monitor = local 2019 "/reverse_proxy/upstreams";
          widget = {
            type = "caddy";
            url = local 2019 "";
          };
        })
      ];
    }
  ];
  shown = lib.filter (group: group.tiles != [ ]) groups;

  bookmark = name: href: icon: { ${name} = [ { inherit href icon; } ]; };
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
      # ./theme.nix replaces this palette with Birds of Paradise.
      color = "slate";
      inherit (theme) background;
      # Blur behind the tiles, so text stays readable over the wallpaper.
      cardBlur = "sm";
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

    customCSS = theme.css;
    customJS = theme.js;

    services = map (group: { ${group.name} = group.tiles; }) shown;

    bookmarks = [
      {
        Links = [
          (bookmark "Proton Mail" "https://mail.proton.me" "proton-mail.svg")
          (bookmark "Dotfiles" "https://github.com/jadeezomg/dotfiles" "github.svg")
          (bookmark "NixOS search" "https://search.nixos.org/packages?channel=unstable" "nixos.svg")
          (bookmark "Tailscale" "https://login.tailscale.com/admin/machines" "tailscale.svg")
          (bookmark "Cloudflare" "https://dash.cloudflare.com" "cloudflare.svg")
        ];
      }
    ];

    widgets = [
      {
        search = {
          provider = "custom";
          url = "https://kagi.com/search?q=";
          suggestionUrl = "https://kagi.com/api/autosuggest?q=";
          showSearchSuggestions = true;
          target = "_blank";
        };
      }
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

  services.caddy.virtualHosts = mkTsnetProxy {
    inherit domain port;
    extra = theme.caddyRoute;
  };
}
