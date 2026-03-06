# NixOS default profile: composed from shared settings/search/extensions and spaces/pins.
# Run sync_caya_from_session.py on NixOS to update spaces.nix and pins.nix from the live Zen session.
{
  pkgs,
  extensions,
  ...
}: let
  sharedSettings = import ../settings.nix;
  sharedSearch = import ../search.nix {inherit pkgs;};
  spaces = import ./spaces.nix {};
  pinsModule = import ./pins.nix {};
in
  {
    settings =
      sharedSettings
      // {
        "zen.workspaces.natural-scroll" = true;
        "zen.widget.linux.transparency" = true;
      };

    search = sharedSearch;

    profileExtensions = {
      "78272b6fa58f4a1abaac99321d503a20@proton.me" = extensions.mkExtensionEntry {
        id = "proton-pass";
        pinned = true;
      };
      "amptra@keepa.com" = extensions.mkExtensionEntry {
        id = "keepa";
        pinned = false;
      };
      "jid1-OY8Xu5BsKZQa6A@jetpack" = extensions.mkExtensionEntry {
        id = "jdownloader";
        url = "https://extensions.jdownloader.org/firefox.xpi";
        pinned = false;
      };
    };

    containersForce = true;
    containers = {
      Shopping = {
        color = "yellow";
        icon = "dollar";
        id = 1;
      };
    };
  }
  // spaces
  // pinsModule
