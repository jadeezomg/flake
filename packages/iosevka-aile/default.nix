{
  pkgs,
  lib,
  ...
}: let
  # Iosevka Aile - Pre-built from GitHub releases
  # To update: change version and run: nix-prefetch-url --unpack <url>
  pname = "iosevka-aile";
  version = "33.3.6";

  src = pkgs.fetchzip {
    url = "https://github.com/be5invis/Iosevka/releases/download/v${version}/PkgTTC-IosevkaAile-${version}.zip";
    sha256 = "sha256-yzI1qjFOUmB8GbaXuZtw7G8bXeOQaObM8O57NLH0WJc=";
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
      description = "Iosevka Aile - A customizable typeface family based on Iosevka (quasi-proportional, sans-serif)";
      homepage = "https://github.com/be5invis/Iosevka";
      license = licenses.ofl;
      maintainers = [];
      platforms = platforms.all;
    };
  }
