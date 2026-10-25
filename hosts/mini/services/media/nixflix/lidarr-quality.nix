# Lidarr quality profile: MP3-320 is the target, not FLAC. Lidarr ranks the
# qualities in a profile and upgrades until the cutoff, so FLAC sits below
# MP3-320: an album that only exists in FLAC is grabbed in FLAC, then
# replaced once a 320 shows up. That keeps the library small; replaced files
# wait 7 days in /Music/.recycle (arr.nix).
#
# nixflix matches profiles by name and deletes undeclared ones. This profile
# is Lidarr's ID 1 (renamed from "Any" on 2026-10-25), which is also the
# default for new artists in nixflix's root folder.
{ lib, ... }:
let
  quality = allowed: id: name: {
    quality = { inherit id name; };
    items = [ ];
    inherit allowed;
  };
  group = allowed: id: name: qualities: {
    inherit id name allowed;
    items = map (q: quality allowed (builtins.elemAt q 0) (builtins.elemAt q 1)) qualities;
  };
  # Lowest to highest priority. Lidarr requires every quality once.
  items = [
    (quality false 0 "Unknown")
    # 224 kbps and below: audibly worse.
    (group false 1000 "Rejected Lossy" [
      [
        32
        "MP3-8"
      ]
      [
        31
        "MP3-16"
      ]
      [
        30
        "MP3-24"
      ]
      [
        29
        "MP3-32"
      ]
      [
        28
        "MP3-40"
      ]
      [
        27
        "MP3-48"
      ]
      [
        26
        "MP3-56"
      ]
      [
        25
        "MP3-64"
      ]
      [
        24
        "MP3-80"
      ]
      [
        23
        "MP3-96"
      ]
      [
        33
        "MP3-112"
      ]
      [
        22
        "MP3-128"
      ]
      [
        19
        "OGG Vorbis Q5"
      ]
      [
        5
        "MP3-160"
      ]
      [
        1
        "MP3-192"
      ]
      [
        18
        "OGG Vorbis Q6"
      ]
      [
        9
        "AAC-192"
      ]
      [
        20
        "WMA"
      ]
      [
        34
        "MP3-224"
      ]
    ])
    # Hi-res and uncommon lossless: large for no audible gain.
    (group false 1001 "Rejected Lossless" [
      [
        35
        "APE"
      ]
      [
        36
        "WavPack"
      ]
      [
        21
        "FLAC 24bit"
      ]
      [
        37
        "ALAC 24bit"
      ]
      [
        13
        "WAV"
      ]
    ])
    # Last resort, upgraded later.
    (group true 1002 "Mid Lossy" [
      [
        17
        "OGG Vorbis Q7"
      ]
      [
        8
        "MP3-VBR-V2"
      ]
      [
        3
        "MP3-256"
      ]
      [
        16
        "OGG Vorbis Q8"
      ]
      [
        10
        "AAC-256"
      ]
    ])
    # Fallback when no high-quality lossy release exists.
    (group true 1003 "Lossless" [
      [
        6
        "FLAC"
      ]
      [
        7
        "ALAC"
      ]
    ])
    # Same quality as MP3-320, often smaller.
    (group true 1004 "High Lossy" [
      [
        2
        "MP3-VBR-V0"
      ]
      [
        12
        "AAC-VBR"
      ]
      [
        15
        "OGG Vorbis Q9"
      ]
      [
        11
        "AAC-320"
      ]
      [
        14
        "OGG Vorbis Q10"
      ]
    ])
    (quality true 4 "MP3-320")
  ];

  qualityIds = lib.concatMap (
    i: if i ? quality then [ i.quality.id ] else map (c: c.quality.id) i.items
  ) items;
in
{
  nixflix.lidarr.config.qualityProfiles = [
    {
      name = "Efficient MP3";
      upgradeAllowed = true;
      cutoff = 4; # MP3-320
      inherit items;
    }
  ];

  # Lidarr 3.1 has 38 qualities and rejects a profile without all of them.
  assertions = [
    {
      assertion = builtins.length qualityIds == 38 && lib.unique qualityIds == qualityIds;
      message = "lidarr-quality.nix: the Efficient MP3 profile must list each of the 38 Lidarr qualities once.";
    }
  ];
}
