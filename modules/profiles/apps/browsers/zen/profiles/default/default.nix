# NixOS default profile: composed from shared settings/search/extensions and spaces/pins.
# Regenerate spaces.nix / pins.nix from the live session: zen_session.py sync (scripts/zen-session).
{
  extensions,
  sharedSearch,
  sharedSettings,
  ...
}: let
  spaces = import ./spaces.nix {};
  pinsModule = import ./pins.nix {};
in
  {
    settings =
      sharedSettings
      // {
        "zen.workspaces.natural-scroll" = true;
        "zen.widget.linux.transparency" = true;
        "widget.dmabuf.force-enabled" = true;
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
      Private = {
        color = "purple";
        icon = "fence";
        id = 2;
      };
    };
  }
  // spaces
  // pinsModule
