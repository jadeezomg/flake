{
  pkgs,
  lib,
  ...
}: let
  # Iosevka Etoile - Pre-built from GitHub releases
  # To update: change version and run: nix-prefetch-url --unpack <url>
  pname = "iosevka-etoile";
<<<<<<< HEAD
  version = "34.6.3";

  src = pkgs.fetchzip {
    url = "https://github.com/be5invis/Iosevka/releases/download/v${version}/PkgTTC-IosevkaEtoile-${version}.zip";
    sha256 = "sha256-ktQ/fp5+E+kFmMUSdyYeXjri7Lrtl4kt+0mu+hfYFsk=";
=======
  version = "34.6.2";

  src = pkgs.fetchzip {
    url = "https://github.com/be5invis/Iosevka/releases/download/v${version}/PkgTTC-IosevkaEtoile-${version}.zip";
    sha256 = "sha256-jo8NYxinj7OGpiVC/rMlSWrVGVWX+5t3UzGA8igputk=";
>>>>>>> 84c4a091f50c5e6bb8af7a4f76a9d96ae4676728
    stripRoot = false;
  };
in
  pkgs.stdenv.mkDerivation {
    inherit pname version;

    inherit src;

    installPhase = ''
      runHook preInstall

      # Install TTC font files
      mkdir -p $out/share/fonts/truetype
      find . -name "*.ttc" -exec install -m 444 {} $out/share/fonts/truetype/ \;

      # Also install TTF files if present
      find . -name "*.ttf" -exec install -m 444 {} $out/share/fonts/truetype/ \;

      runHook postInstall
    '';

    meta = with lib; {
      description = "Iosevka Etoile - A customizable typeface family based on Iosevka (quasi-proportional, slab-serif)";
      homepage = "https://github.com/be5invis/Iosevka";
      license = licenses.ofl;
      maintainers = [];
      platforms = platforms.all;
    };
  }
