{ dotfilesLib, lib, ... }@args:
let
  inherit (dotfilesLib.expiry { inherit lib; } "modules/profiles/apps/media.nix") todo;
in
dotfilesLib.mkProfile {
  path = [ "apps" ];
  # HM half: pear-desktop desktop entry and custom YouTube Music CSS.
  hm = [
    ./media/home.nix
    {
      xdg.desktopEntries."pear-desktop" = {
        name = "Pear Desktop";
        genericName = "YouTube Music Desktop";
        exec = "pear-desktop";
        icon = "pear-desktop";
        terminal = false;
        categories = [
          "Audio"
          "Music"
          "Player"
        ];
        comment = "YouTube Music Desktop Client";
      };
    }
  ];

  packages =
    pkgs: with pkgs; [
      pear-desktop # YouTube Music desktop client
      gradia # Screenshot annotation
      pinta # Lightweight raster editor
      readest # Modern, feature-rich ebook reader
    ];

  # The bundled CEF browser plugin is about 2 GiB. Dropping it via
  # `obs-studio.override { browserSupport = false; }` is not in the binary
  # cache, so it forces a local OBS build. The guard warns until you decide.
  extra.programs.obs-studio.enable = todo "OBS ships the 2 GiB CEF plugin; decide: keep, drop OBS, or install it as a flatpak" true;
} args
