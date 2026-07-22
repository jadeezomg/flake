{
  config,
  lib,
  ...
}:
let
  inherit (import ./common.nix) mkLibrary;
in
{
  nixflix.jellyfin = {
    enable = true;
    dataDir = "/srv/nixflix/jellyfin";
    cacheDir = "/srv/nixflix/jellyfin-cache";
    apiKey._secret = config.sops.secrets."mini/media/jellyfin/api-key".path;

    system.metadataPath = "/srv/nixflix/jellyfin/metadata";
    network = {
      localNetworkAddresses = [ "127.0.0.1" ];
      knownProxies = [ "127.0.0.1" ];
      localNetworkSubnets = [
        "192.168.178.0/24"
        "100.64.0.0/10"
      ];
    };

    users = {
      jadee = {
        mutable = false;
        password._secret = config.sops.secrets."mini/media/jellyfin/users/jadee-password".path;
        policy = {
          isAdministrator = true;
          isHidden = false;
        };
      };
      angeli265 = {
        mutable = false;
        password._secret = config.sops.secrets."mini/media/jellyfin/users/angeli265-password".path;
        policy.isHidden = false;
      };
    };

    encoding = {
      enableHardwareEncoding = true;
      hardwareAccelerationType = "qsv";
      qsvDevice = "/dev/dri/renderD128";
      hardwareDecodingCodecs = [
        "h264"
        "hevc"
        "mpeg2video"
        "vc1"
        "vp8"
        "vp9"
        "av1"
      ];
      allowAv1Encoding = false;
      enableIntelLowPowerH264HwEncoder = false;
      enableIntelLowPowerHevcHwEncoder = false;
    };

    libraries = {
      Shows = lib.mkForce null;
      Movies = lib.mkForce (mkLibrary "movies" [ "/media/Cinema" ]);
      Music = lib.mkForce (mkLibrary "music" [ "/media/Music" ]);
      Series = mkLibrary "tvshows" [ "/media/Series" ];
      "ゲーム" = mkLibrary "tvshows" [ "/media/Anime" ];
      "Documentaries Feature" = mkLibrary "movies" [ "/media/Documentaries Feature" ];
      Documentaries = mkLibrary "tvshows" [ "/media/Documentaries" ];
      Comedy = mkLibrary "movies" [ "/media/Comedy" ];
      "Gaming Videos" = mkLibrary "movies" [ "/media/Movies" ];
      "Series-PtBr" = mkLibrary "tvshows" [ "/media/Series-PtBr" ];
    };
  };

  systemd.services = {
    jellyfin.serviceConfig = {
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/nixflix/jellyfin"
        "/srv/nixflix/jellyfin-cache"
      ];
      ReadOnlyPaths = [ "/media" ];
      InaccessiblePaths = [
        "/data"
        "/Music"
      ];
    };
  };
}
