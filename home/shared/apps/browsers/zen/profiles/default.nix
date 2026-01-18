{
  pkgs,
  extensions,
  ...
}: let
  sharedSettings = import ../settings.nix;
  sharedSearch = import ../search.nix {inherit pkgs;};
in rec {
  settings =
    sharedSettings
    // {
      "zen.workspaces.natural-scroll" = false;
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

  pinsForce = true;
  pins = {
    # Top row (101-103)
    "Proton Mail" = {
      id = "5855f1ce-a12a-4065-8965-dd1a71f76a5c";
      url = "https://mail.proton.me";
      position = 101;
      isEssential = true;
    };
    "YouTube" = {
      id = "5ad224b2-5596-4268-b492-d7a781ea7c8e";
      url = "https://www.youtube.com";
      position = 102;
      isEssential = true;
    };
    "Discord" = {
      id = "87e179f9-4f46-4aeb-bc0f-fca09b5fff23";
      url = "https://discord.com";
      position = 103;
      isEssential = true;
    };
    # Middle row (104-106)
    "Reddit" = {
      id = "eaf54047-7d5f-423e-b695-c794b3df0e82";
      url = "https://www.reddit.com";
      position = 104;
      isEssential = true;
    };
    "Bluesky" = {
      id = "f78b129b-b4c8-4de1-9c6b-fd8254efde8a";
      url = "https://bsky.app";
      position = 105;
      isEssential = true;
    };
    "WhatsApp Web" = {
      id = "5117b79f-7b69-4763-a804-683b413c9611";
      url = "https://web.whatsapp.com/";
      position = 106;
      isEssential = true;
    };
    # Bottom row (107-109)
    "GitHub" = {
      id = "27762ade-30f6-4895-b348-b0410e9d858b";
      url = "https://github.com";
      position = 107;
      isEssential = true;
    };
    "Le Chat" = {
      id = "9760b4d1-ab39-43d7-8fba-3b8232b04ad1";
      url = "https://chat.mistral.ai";
      position = 108;
      isEssential = true;
    };
    "jadee-server" = {
      id = "6a7a0766-9e1d-48a3-a14b-42a79ba85bc0";
      url = "http://jadee-server";
      position = 109;
      isEssential = true;
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

  spacesForce = true;
  spaces = {
    "Home" = {
      id = "062169cd-2322-44e2-aea5-467df4671303";
      icon = "🏠";
      position = 1000;
    };
    "Development" = {
      id = "5303cb0f-97f9-4bb1-b859-108214314758";
      icon = "💻";
      position = 1001;
    };
    "Shopping" = {
      id = "90801cc0-78d5-469b-a53a-cdb26aa2ae8d";
      icon = "🛒";
      position = 1002;
    };
    "Themes" = {
      id = "b878e1a6-6347-4070-bd19-00b74db05d12";
      icon = "🎨";
      position = 1003;
    };
    "Games" = {
      id = "9f311082-5623-47b5-960d-2a7b115b238e";
      icon = "🎮";
      position = 1004;
    };
    "Downloads" = {
      id = "fdcbe00e-21e9-46aa-93f5-52676ecb2301";
      icon = "💾";
      position = 1005;
    };
  };
}
