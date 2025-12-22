{
  pkgs,
  lib,
  ...
}: let
  # Iosevka Etoile - Pre-built from GitHub releases
  # To update: change version and run: nix-prefetch-url --unpack <url>
  pname = "iosevka-etoile";
  version = "33.3.6";

  src = pkgs.fetchzip {
    url = "https://github.com/be5invis/Iosevka/releases/download/v${version}/PkgTTC-IosevkaEtoile-${version}.zip";
    sha256 = "sha256-2Cm7K1TgPvB0zUIbprtNdGpKlGKl+IiNgls0855J6fg=";
    stripRoot = false;
  };
in
  pkgs.stdenv.mkDerivation {
    inherit pname version;

    src = src;

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
