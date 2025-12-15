final: prev: {
  pear-desktop = prev.appimageTools.wrapType2 rec {
    pname = "pear-desktop";

    # To update to latest version, run: ./overlays/update-pear-desktop.sh
    # This will automatically fetch the latest release and update version/hash
    version = "3.11.0";
    sha512 = "441478232b6bc64b9d28432876aec9cab014bddfeece61c088603816371171a040370ea9d1470ca0727a772154cb891046d330eff3b3552b808b2f7fbd4a9f6b";

    src = prev.fetchurl {
      url = "https://github.com/pear-devs/pear-desktop/releases/download/v${version}/YouTube-Music-${version}.AppImage";
      inherit sha512;
    };

    extraPkgs = prev.appimageTools.defaultFhsEnvArgs.multiPkgs;

    meta = with prev.lib; {
      description = "Native look & feel extension for YouTube Music desktop client";
      homepage = "https://github.com/pear-devs/pear-desktop";
      license = licenses.mit;
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  };
}
