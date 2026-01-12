{
  pkgs,
  extensions,
  ...
}: let
  sharedSettings = import ../settings.nix;
in rec {
  id = 1;
  isDefault = !pkgs.stdenv.isLinux;
  settings =
    sharedSettings
    // {
      "zen.workspaces.natural-scroll" = true;
    };

  profileExtensions = {
    "{d634138d-c276-4fc8-924b-40a0ea21d284}" = extensions.mkExtensionEntry {
      id = "1password-x-password-manager";
      pinned = true;
    };
  };

  pinsForce = true;
  pins = {
    "Gmail" = {
      id = "c1d2e3f4-a5b6-4789-c012-d3e4f5a6b789";
      url = "https://mail.google.com";
      position = 101;
      isEssential = true;
    };
    "Google Calendar" = {
      id = "d2e3f4a5-b6c7-4890-d123-e4f5a6b7c890";
      url = "https://calendar.google.com";
      position = 102;
      isEssential = true;
    };
    "Google Meet" = {
      id = "e3f4a5b6-c7d8-4901-e234-f5a6b7c8d901";
      url = "https://meet.google.com";
      position = 103;
      isEssential = true;
    };
    "Metabase" = {
      id = "f4a5b6c7-d8e9-4012-f345-a6b7c8d9e012";
      url = "https://metabase.example.com";
      position = 104;
      isEssential = true;
    };
    "Google Gemini" = {
      id = "a5b6c7d8-e9f0-4123-a456-b7c8d9e0f123";
      url = "https://gemini.google.com";
      position = 105;
      isEssential = true;
    };
    "Workato" = {
      id = "b6c7d8e9-f0a1-4234-b567-c8d9e0f1a234";
      url = "https://app.workato.com";
      position = 106;
      isEssential = true;
    };
    "Zoho Sprints" = {
      id = "c7d8e9f0-a1b2-4345-c678-d9e0f1a2b345";
      url = "https://sprints.zoho.com";
      position = 107;
      isEssential = true;
    };
    "GitHub" = {
      id = "d8e9f0a1-b2c3-4456-d789-e0f1a2b3c456";
      url = "https://github.com";
      position = 108;
      isEssential = true;
    };
  };

  containersForce = true;
  containers = {
    "Automations" = {
      color = "blue";
      icon = "briefcase";
      id = 1;
    };
    "Forwarding" = {
      color = "yellow";
      icon = "cart";
      id = 2;
    };
  };

  spacesForce = true;
  spaces = {
    "Random" = {
      id = "060b1a27-d488-4c97-a51d-333fdac0eb7c";
      icon = "🏠";
      position = 1000;
    };
    "Solutions" = {
      id = "8a4ea01f-fdf1-4f09-9d76-789cbc8e8fc7";
      icon = "💡";
      position = 1001;
    };
    "Operations" = {
      id = "4a003f39-c69b-4424-90ae-b2ae49d6e632";
      icon = "";
      position = 1002;
    };
    "Development" = {
      id = "8bbf6155-b7cc-4487-9379-35c02d1139ce";
      icon = "💻";
      position = 1003;
    };
    "Research" = {
      id = "278ec41c-2c9d-41b3-aa79-1affeb706629";
      icon = "🔍";
      position = 1004;
    };
  };
}
