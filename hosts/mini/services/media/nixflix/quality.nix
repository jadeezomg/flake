# Radarr/Sonarr quality profiles, custom formats, and size limits, synced by
# Recyclarr every day. Our custom formats are not in the TRaSH guide, so they
# go to Recyclarr as local JSON files (a `custom-formats` resource provider).
#
# All profiles share one ladder. Every 720p/1080p/2160p quality sits in one
# quality group, so Radarr/Sonarr rank releases by custom format score alone:
#   1. efficient 4K   2. 1080p   3. high-bitrate 4K   4. 720p
# Radarr splits 4K by size and gates 1080p/720p by size. Sonarr cannot (its
# Size condition measures a whole season pack), so it splits 4K by codec.
#
# TRaSH "unwanted" formats (low quality, upscaled, retagged, ...) are rejected
# in every profile; Sonarr prefers season packs.
#
# Profiles not listed here are deleted after each sync. Their movies and
# series move to the first profile (recyclarr-cleanup-profiles).
{ lib, pkgs, ... }:
let
  inherit (lib) mapAttrsToList;

  # Profile names. Seerr finds its default by name (../seerr.nix).
  originalEn = "Original + EN Subs";
  german = "German Audio";
  ptBr = "PT-BR Audio + Subs";

  # Format names are the key between this file and the Arr services.
  # Renaming one makes Recyclarr create a new format and drop the old one.
  langOriginal = "Lang: Original";
  langGerman = "Lang: German";
  langPtBr = "Lang: PT-BR";
  subsEn = "Subs: English";
  subsPtBr = "Subs: PT-BR";
  av1 = "Codec: AV1";
  hevc = "Codec: HEVC";
  webDl = "Source: WEB-DL";
  webRip = "Source: WEBRip";
  tier4k = "Tier 1: 4K efficient";
  tier1080 = "Tier 2: 1080p";
  tier4kBig = "Tier 3: 4K high bitrate";
  tier720 = "Tier 4: 720p";

  # Scores. Each band is larger than the sum of all bands below it, so a
  # tiebreak never lifts a release into a better tier.
  langScore = 100000;
  tierScores = {
    ${tier4k} = 40000;
    ${tier1080} = 30000;
    ${tier4kBig} = 20000;
    ${tier720} = 10000;
  };
  tiebreakScores = {
    ${av1} = 600;
    ${hevc} = 400;
    ${webDl} = 200;
    ${webRip} = 150;
  };
  subsScore = 500;
  # Dual-audio releases that also keep the original track win.
  originalBonus = 2000;
  # Sonarr: one download per season beats single episodes in the same tier.
  seasonPackScore = 1500;
  # TRaSH "unwanted" formats: no release with one can reach min_format_score.
  rejectScore = -1000000;

  # Formats from the TRaSH guide, by trash_id (Recyclarr's official provider).
  guide = {
    radarr = {
      # Rejected in every profile.
      junk = [
        "ed38b889b31be83fda192888e2286d83" # BR-DISK
        "90a6f9a284dff5103f6346090e6280c8" # LQ
        "e204b80c87be9497a8a6eaff48f72905" # LQ (Release Title)
        "b8cd450cbfa689c0259a01d9e29ba3d6" # 3D
        "0a3f082873eb454bde444150b70253cc" # Extras
        "712d74cd88bceb883ee32f773656b1f5" # Sing-Along Versions
        "bfd8eb01832d646a0a89c4deb46f8564" # Upscaled
        "5c44f52a8714fdd79bb4d98e2673be1f" # Retags
        "7357cf5161efbf8c4d5d0c30b4815ee2" # Obfuscated
      ];
      # Rejected in the original-language profile only: many German and
      # PT-BR dual-audio releases come from these groups.
      # No No-RlsGroup: it also scores existing files, and most library files
      # have no group in their name, so every release became an upgrade.
      junkOriginalOnly = [
        "b6832f586342ef70d9c128d40c07b872" # Bad Dual Groups
      ];
      bonus = { };
    };
    sonarr = {
      junk = [
        "85c61753df5da1fb2aab6f2a47426b09" # BR-DISK
        "9c11cd3f07101cdba90a2d81cf0e56b4" # LQ
        "e2315f990da2e2cbfc9fa5b7a6fcfe48" # LQ (Release Title)
        "fbcb31d8dabd2a319072b84fc0b7249c" # Extras
        "23297a736ca77c0fc8e70f8edd7ee56c" # Upscaled
        "06d66ab109d4d2eddb2794d21526d140" # Retags
        "e1a997ddb54e3ecbfe06341ad323c458" # Obfuscated
      ];
      junkOriginalOnly = [
        "32b367365729d530ca1c124a0b180c64" # Bad Dual Groups
      ];
      bonus = {
        "3bc5f395426614e155e585a2f056cdf1" = seasonPackScore; # Season Pack
      };
    };
  };

  spec = implementation: name: fields: {
    inherit implementation name fields;
    negate = false;
    required = false;
  };
  required = s: s // { required = true; };
  negated = s: s // { negate = true; };
  language =
    name: id:
    spec "LanguageSpecification" name {
      value = id;
      exceptLanguage = false;
    };
  title = name: regex: spec "ReleaseTitleSpecification" name { value = regex; };
  resolution = r: required (spec "ResolutionSpecification" "${toString r}p" { value = r; });
  sizeGb =
    min: max:
    required (
      spec "SizeSpecification" "${toString min}-${toString max} GB" {
        inherit min max;
      }
    );

  efficientCodec = ''\b(?:AV1|AV01|x265|h[ ._-]?265|HEVC)\b'';

  # Service-specific enum values: source and Portuguese (Brazil) differ.
  sharedFormats = ids: {
    ${langOriginal} = [ (language "Original audio" (-2)) ];
    ${langGerman} = [ (language "German audio" 4) ];
    ${langPtBr} = [ (language "Portuguese (Brazil) audio" ids.ptBr) ];
    ${subsEn} = [
      (title "English subtitles in release name" ''\b(?:ENG(?:LISH)?[ ._-]?(?:SUBS?|SUBTITLES?)|SUBS?[ ._-]?ENG)\b'')
    ];
    ${subsPtBr} = [
      (title "PT-BR subtitles in release name" ''\b(?:LEGENDADO|LEG|PT[ ._-]?BR[ ._-]?SUBS?)\b'')
    ];
    ${av1} = [ (title "AV1 codec" ''\b(?:AV1|AV01)\b'') ];
    ${hevc} = [ (title "HEVC codec" ''\b(?:x265|h[ ._-]?265|HEVC)\b'') ];
    ${webDl} = [ (spec "SourceSpecification" "WEB-DL source" { value = ids.webDl; }) ];
    ${webRip} = [ (spec "SourceSpecification" "WEBRip source" { value = ids.webRip; }) ];
  };

  # Size condition: release size > min and <= max, in GB.
  radarrFormats =
    sharedFormats {
      webDl = 7;
      webRip = 8;
      ptBr = 30;
    }
    // {
      ${tier4k} = [
        (resolution 2160)
        (sizeGb 0 15)
      ];
      ${tier1080} = [
        (resolution 1080)
        (sizeGb 5 12)
      ];
      # "No cap": the largest size Radarr accepts. Remux is not in the group.
      ${tier4kBig} = [
        (resolution 2160)
        (sizeGb 15 1000)
      ];
      ${tier720} = [
        (resolution 720)
        (sizeGb 2 8)
      ];
    };

  sonarrFormats =
    sharedFormats {
      webDl = 3;
      webRip = 4;
      ptBr = 33;
    }
    // {
      ${tier4k} = [
        (resolution 2160)
        (required (title "AV1 or HEVC" efficientCodec))
      ];
      ${tier1080} = [ (resolution 1080) ];
      ${tier4kBig} = [
        (resolution 2160)
        (required (negated (title "Not AV1 or HEVC" efficientCodec)))
      ];
      ${tier720} = [ (resolution 720) ];
    };

  # Recyclarr wants a stable trash_id per format; derive it from the name.
  trashId = name: builtins.hashString "md5" "dotfiles/${name}";
  slug = name: lib.toLower (lib.replaceStrings [ " " ":" "+" ] [ "-" "" "plus" ] name);

  formatDir =
    service: formats:
    pkgs.linkFarm "recyclarr-${service}-custom-formats" (
      mapAttrsToList (name: specifications: {
        name = "${slug name}.json";
        path = pkgs.writeText "${slug name}.json" (
          builtins.toJSON {
            trash_id = trashId name;
            inherit name specifications;
            includeCustomFormatWhenRenaming = false;
          }
        );
      }) formats
    );

  settings = (pkgs.formats.yaml { }).generate "recyclarr-settings.yml" {
    resource_providers = [
      {
        name = "dotfiles-radarr";
        type = "custom-formats";
        service = "radarr";
        path = "${formatDir "radarr" radarrFormats}";
      }
      {
        name = "dotfiles-sonarr";
        type = "custom-formats";
        service = "sonarr";
        path = "${formatDir "sonarr" sonarrFormats}";
      }
    ];
  };

  # Profile name -> required language format and its bonus formats.
  profiles = {
    ${originalEn} = {
      lang = langOriginal;
      bonus = {
        ${subsEn} = subsScore;
      };
    };
    ${german} = {
      lang = langGerman;
      bonus = {
        ${langOriginal} = originalBonus;
      };
    };
    ${ptBr} = {
      lang = langPtBr;
      bonus = {
        ${langOriginal} = originalBonus;
        ${subsPtBr} = subsScore;
      };
    };
  };
  # The first one receives the media of deleted profiles.
  profileOrder = [
    originalEn
    german
    ptBr
  ];

  scoresFor = p: { ${p.lang} = langScore; } // tierScores // tiebreakScores // p.bonus;

  ladderGroup = "720p-2160p";
  ladder =
    map
      (res: [
        "Bluray-${res}"
        "WEBDL-${res}"
        "WEBRip-${res}"
        "HDTV-${res}"
      ])
      [
        "2160p"
        "1080p"
        "720p"
      ];

  qualityProfile = name: {
    inherit name;
    reset_unmatched_scores.enabled = true;
    upgrade = {
      allowed = true;
      until_quality = ladderGroup;
      # Stop once an efficient 4K with HEVC or better is found.
      until_score = langScore + tierScores.${tier4k} + tiebreakScores.${hevc};
    };
    min_format_score = langScore + tierScores.${tier720};
    min_upgrade_format_score = 1;
    # Unlisted qualities (SD, Remux, BR-DISK) end up disabled.
    qualities = [
      {
        name = ladderGroup;
        enabled = true;
        qualities = lib.concatLists ladder;
      }
    ];
  };

  scoreFor = profileNames: score: map (name: { inherit name score; }) profileNames;
  guideFormats =
    g:
    [
      {
        trash_ids = g.junk;
        assign_scores_to = scoreFor profileOrder rejectScore;
      }
      {
        trash_ids = g.junkOriginalOnly;
        assign_scores_to = scoreFor [ originalEn ] rejectScore;
      }
    ]
    ++ mapAttrsToList (id: score: {
      trash_ids = [ id ];
      assign_scores_to = scoreFor profileOrder score;
    }) g.bonus;

  # One custom_formats entry per format, listing the profiles that score it.
  customFormats =
    formats:
    mapAttrsToList (name: _: {
      trash_ids = [ (trashId name) ];
      assign_scores_to = lib.concatMap (
        profileName:
        let
          scores = scoresFor profiles.${profileName};
        in
        lib.optional (scores ? ${name}) {
          name = profileName;
          score = scores.${name};
        }
      ) profileOrder;
    }) formats;

  # MB per minute. Remux and the other qualities keep the guide values.
  sizes =
    limits:
    lib.concatLists (
      mapAttrsToList (
        res: limit:
        map (name: { inherit name; } // limit) [
          "HDTV-${res}"
          "WEBDL-${res}"
          "WEBRip-${res}"
          "Bluray-${res}"
        ]
      ) limits
    );

  # Torrents wait 60 min so a usenet release can win. Every quality sits in
  # the one ladder group, so "highest quality" would bypass the delay for
  # every release; bypass only at the upgrade target score instead.
  delayProfiles = [
    {
      id = 1;
      order = 2147483647; # the default profile, for all tags
      enableUsenet = true;
      enableTorrent = true;
      preferredProtocol = "usenet";
      usenetDelay = 0;
      torrentDelay = 60;
      bypassIfHighestQuality = false;
      bypassIfAboveCustomFormatScore = true;
      minimumCustomFormatScore = langScore + tierScores.${tier4k} + tiebreakScores.${hevc};
      tags = [ ];
    }
  ];

  instance = formats: guideSet: qualityDefinition: {
    quality_definition = qualityDefinition;
    quality_profiles = map qualityProfile profileOrder;
    custom_formats = customFormats formats ++ guideFormats guideSet;
  };
in
{
  nixflix.radarr.config = { inherit delayProfiles; };
  nixflix.sonarr.config = { inherit delayProfiles; };

  nixflix.recyclarr = {
    enable = true;

    cleanupUnmanagedProfiles = {
      enable = true;
      managedProfiles = profileOrder;
    };

    config = {
      radarr.radarr = instance radarrFormats guide.radarr {
        type = "movie";
        qualities = sizes {
          # The 720p and 1080p maxima leave room for the tier formats (8 GB
          # and 12 GB on a 90-minute movie); those formats set the range.
          "720p" = {
            min = 8;
            preferred = 35;
            max = 100;
          };
          "1080p" = {
            min = 10;
            preferred = 45;
            max = 135;
          };
          # No cap, so tier 3 can exist. Tier 1 keeps 4K at <= 15 GB.
          "2160p" = {
            min = 25;
            preferred = 85;
            max = "unlimited";
          };
        };
      };

      sonarr.sonarr = instance sonarrFormats guide.sonarr {
        type = "series";
        qualities = sizes {
          "1080p" = {
            min = 8;
            preferred = 40;
            max = 70;
          };
          "2160p" = {
            min = 20;
            preferred = 60;
            max = "unlimited";
          };
        };
      };
    };
  };

  # Recyclarr reads settings.yml from RECYCLARR_CONFIG_DIR (/var/lib/recyclarr).
  systemd.services.recyclarr.preStart = lib.mkAfter ''
    ln -sfn ${settings} /var/lib/recyclarr/settings.yml
  '';
}
