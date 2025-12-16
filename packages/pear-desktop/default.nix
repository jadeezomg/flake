{
  pkgs,
  lib,
  ...
}: let
  # To update to latest version, run: ./packages/pear-desktop/update.sh
  # This will automatically fetch the latest release and update version/hash
  pname = "pear-desktop";
  version = "3.11.0";
  name = "${pname}-${version}";

  src = pkgs.fetchurl {
    url = "https://github.com/pear-devs/pear-desktop/releases/download/v${version}/YouTube-Music-${version}.AppImage";
    sha512 = "441478232b6bc64b9d28432876aec9cab014bddfeece61c088603816371171a040370ea9d1470ca0727a772154cb891046d330eff3b3552b808b2f7fbd4a9f6b";
  };

  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;
    pkgs = pkgs;

    extraPkgs = pkgs.appimageTools.defaultFhsEnvArgs.multiPkgs;

    extraInstallCommands = ''
      # Try to install desktop file (try direct path first, then search)
      if [ -f ${appimageContents}/${pname}.desktop ]; then
        install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
      else
        desktopFile=$(ls ${appimageContents}/usr/share/applications/*.desktop 2>/dev/null | head -1)
        if [ -n "$desktopFile" ]; then
          install -m 444 -D "$desktopFile" $out/share/applications/${pname}.desktop
        fi
      fi

      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace 'Exec=AppRun' 'Exec=${pname}'

      # Copy icons
      if [ -d ${appimageContents}/usr/share/icons ]; then
        cp -r ${appimageContents}/usr/share/icons $out/share
      fi

      # Unless linked, the binary is placed in $out/bin/${pname}-${version}
      # Create symlink for simpler name
      if [ -f $out/bin/${pname}-${version} ]; then
        ln -s $out/bin/${pname}-${version} $out/bin/${pname}
      fi
    '';

    extraBwrapArgs = [
      "--bind-try /etc/nixos/ /etc/nixos/"
    ];

    meta = with lib; {
      description = "Native look & feel extension for YouTube Music desktop client";
      homepage = "https://github.com/pear-devs/pear-desktop";
      license = licenses.mit;
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  }
