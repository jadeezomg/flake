{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.zen-browser.homeModules.twilight
  ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = lib.optionals pkgs.stdenv.isLinux [pkgs.firefoxpwa];

    policies = let
      mkLockedAttrs = builtins.mapAttrs (
        _: value: {
          Value = value;
          Status = "locked";
        }
      );
      mkPluginUrl = id: "https://addons.mozilla.org/firefox/downloads/latest/${id}/latest.xpi";

      mkExtensionEntry = {
        id,
        pinned ? false,
      }: let
        base = {
          install_url = mkPluginUrl id;
          installation_mode = "force_installed";
        };
      in
        if pinned
        then base // {default_area = "navbar";}
        else base;

      mkExtensionSettings = builtins.mapAttrs (
        _: entry:
          if builtins.isAttrs entry
          then entry
          else mkExtensionEntry {id = entry;}
      );
    in {
      AutofillAddressEnabled = true;
      AutofillCreditCardEnabled = false;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisableAppUpdate = true;
      DisableTelemetry = true;
      OfferToSaveLogins = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      SanitizeOnShutdown = {
        FormData = true;
        Cache = true;
      };

      ExtensionSettings = mkExtensionSettings (
        {
          "uBlock0@raymondhill.net" = "ublock-origin";
          "gdpr@cavi.au.dk" = "consent-o-matic";
          "addon@darkreader.org" = "darkreader";
          "{91aa3897-2634-4a8a-9092-279db23a7689}" = "zen-internet";
          "{74145f27-f039-47ce-a470-a662b129930a}" = "clearurls";
          "{BraveSearchExtension@io.Uvera}" = "brave-search";
        }
        // (
          # Password manager: Platform-specific
          if pkgs.stdenv.isLinux
          then {
            # Proton Pass on NixOS
            "78272b6fa58f4a1abaac99321d503a20@proton.me" = mkExtensionEntry {
              id = "proton-pass";
              pinned = true;
            };
            "amptra@keepa.com" = mkExtensionEntry {
              id = "keepa";
              pinned = false;
            };
          }
          else {
            # 1Password on Darwin
            "{d634138d-c276-4fc8-924b-40a0ea21d284}" = mkExtensionEntry {
              id = "1password-x-password-manager";
              pinned = true;
            };
          }
        )
      );
      Preferences = mkLockedAttrs {
        # General
        "browser.aboutConfig.showWarning" = false;
        "browser.tabs.warnOnClose" = false;
        "media.videocontrols.picture-in-picture.video-toggle.enabled" = true;
        # Disable swipe gestures (Browser:BackOrBackDuplicate, Browser:ForwardOrForwardDuplicate)
        #"browser.gesture.swipe.left" = "";
        #"browser.gesture.swipe.right" = "";
        "browser.tabs.hoverPreview.enabled" = true;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.topsites.contile.enabled" = false;

        # Transparency
        "browser.tabs.allow_transparent_browser" = true;
        "zen.widget.linux.transparency" = true;

        # Privacy
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.randomization.canvas.use_siphash" = true;
        "privacy.resistFingerprinting.randomization.daily_reset.enabled" = true;
        "privacy.resistFingerprinting.randomization.daily_reset.private.enabled" = true;
        "privacy.resistFingerprinting.block_mozAddonManager" = true;
        "privacy.spoof_english" = 1;
        "privacy.firstparty.isolate" = true;
        "network.cookie.cookieBehavior" = 5;
        "dom.battery.enabled" = false;

        # Performance
        "gfx.webrender.all" = true;
        "network.http.http3.enabled" = true;
        "network.socket.ip_addr_any.disabled" = true; # disallow bind to 0.0.0.0
      };
    };

    profiles.default = rec {
      id = 0;
      isDefault = pkgs.stdenv.isLinux; # Default on NixOS (Linux)
      settings = {
        "zen.workspaces.continue-where-left-off" = true;
        "zen.workspaces.natural-scroll" = false;
        "zen.view.compact.hide-tabbar" = true;
        "zen.view.compact.hide-toolbar" = true;
        "zen.view.compact.animate-sidebar" = false;
        "zen.welcome-screen.seen" = true;
        "zen.urlbar.behavior" = "float";
        "zen.workspaces.separate-essentials" = false;
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
    };

    profiles.caya = rec {
      id = 1;
      isDefault = !pkgs.stdenv.isLinux; # Default on Darwin (macOS)
      settings = {
        "zen.workspaces.continue-where-left-off" = true;
        "zen.workspaces.natural-scroll" = true;
        "zen.view.compact.hide-tabbar" = true;
        "zen.view.compact.hide-toolbar" = true;
        "zen.view.compact.animate-sidebar" = false;
        "zen.welcome-screen.seen" = true;
        "zen.urlbar.behavior" = "float";
        "zen.workspaces.separate-essentials" = false;
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
          icon = "�";
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
    };
  };
}
