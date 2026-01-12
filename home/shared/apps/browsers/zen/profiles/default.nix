{
  pkgs,
  extensions,
  ...
}: let
  sharedSettings = import ../settings.nix;
in rec {
  id = 0;
  isDefault = pkgs.stdenv.isLinux;
  settings =
    sharedSettings
    // {
      "zen.workspaces.natural-scroll" = false;
    };

  profileExtensions = {
    "78272b6fa58f4a1abaac99321d503a20@proton.me" = extensions.mkExtensionEntry {
      id = "proton-pass";
      pinned = true;
    };
    "amptra@keepa.com" = extensions.mkExtensionEntry {
      id = "keepa";
      pinned = false;
    };
  };

  pinsForce = true;
  pins = {
    # Top row (101-103)
    "Proton Mail" = {
      id = "a1b2c3d4-e5f6-4789-a012-b3c4d5e6f789";
      url = "https://mail.proton.me";
      position = 101;
      isEssential = true;
    };
    "YouTube" = {
      id = "b2c3d4e5-f6a7-4890-b123-c4d5e6f7a890";
      url = "https://www.youtube.com";
      position = 102;
      isEssential = true;
    };
    "Discord" = {
      id = "c3d4e5f6-a7b8-4901-c234-d5e6f7a8b902";
      url = "https://discord.com";
      position = 103;
      isEssential = true;
    };
    # Middle row (104-106)
    "Reddit" = {
      id = "e5f6a7b8-c9d0-4123-e456-f7a8b9c0d123";
      url = "https://www.reddit.com";
      position = 104;
      isEssential = true;
    };
    "Bluesky" = {
      id = "b7c8d9e0-f1a2-4456-b789-c0d1e2f3a456";
      url = "https://bsky.app";
      position = 105;
      isEssential = true;
    };
    "jadee-server" = {
      id = "f6a7b8c9-d0e1-4234-f567-a8b9c0d1e234";
      url = "http://jadee-server";
      position = 106;
      isEssential = true;
    };
    # Bottom row (107-109)
    "GitHub" = {
      id = "c3d4e5f6-a7b8-4901-c234-d5e6f7a8b901";
      url = "https://github.com";
      position = 107;
      isEssential = true;
    };
    "Le Chat" = {
      id = "d4e5f6a7-b8c9-4012-d345-e6f7a8b9c012";
      url = "https://chat.mistral.ai";
      position = 108;
      isEssential = true;
    };
    "Claude" = {
      id = "a7b8c9d0-e1f2-4345-a678-b9c0d1e2f345";
      url = "https://claude.ai";
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
      id = "572910e1-4468-4832-a869-0b3a93e2f165";
      icon = "🏠";
      position = 1000;
    };
    "Development" = {
      id = "ec287d7f-d910-4860-b400-513f269dee77";
      icon = "💻";
      position = 1001;
    };
    "Shopping" = {
      id = "2441acc9-79b1-4afb-b582-ee88ce554ec0";
      icon = "🛒";
      container = containers."Shopping".id;
      position = 1002;
    };
    "Themes" = {
      id = "8ed24375-68d4-4d37-ab7e-b2e121f994c1";
      icon = "🎨";
      position = 1003;
    };
    "Games" = {
      id = "93162c7e-c086-4393-98d3-3c440215919c";
      icon = "🎮";
      position = 1004;
    };
    "Downloads" = {
      id = "9e5ef3a0-f09e-4a1f-ac60-8591aa289e3e";
      icon = "💾";
      position = 1004;
    };
  };
}
