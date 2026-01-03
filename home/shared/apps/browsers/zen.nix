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

      ExtensionSettings = mkExtensionSettings {
        "78272b6fa58f4a1abaac99321d503a20@proton.me" = mkExtensionEntry {
          id = "proton-pass";
          pinned = true;
        };
        "uBlock0@raymondhill.net" = "ublock-origin";
        "gdpr@cavi.au.dk" = "consent-o-matic";
        "addon@darkreader.org" = "darkreader";
        "{91aa3897-2634-4a8a-9092-279db23a7689}" = "zen-internet";
        "{74145f27-f039-47ce-a470-a662b129930a}" = "clearurls";
        "{BraveSearchExtension@io.Uvera}" = "brave-search";
      };
      Preferences = mkLockedAttrs {
        "browser.aboutConfig.showWarning" = false;
        "browser.tabs.warnOnClose" = false;
        "media.videocontrols.picture-in-picture.video-toggle.enabled" = true;
        # Disable swipe gestures (Browser:BackOrBackDuplicate, Browser:ForwardOrForwardDuplicate)
        #"browser.gesture.swipe.left" = "";
        #"browser.gesture.swipe.right" = "";
        "browser.tabs.hoverPreview.enabled" = true;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.topsites.contile.enabled" = false;

        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.randomization.canvas.use_siphash" = true;
        "privacy.resistFingerprinting.randomization.daily_reset.enabled" = true;
        "privacy.resistFingerprinting.randomization.daily_reset.private.enabled" = true;
        "privacy.resistFingerprinting.block_mozAddonManager" = true;
        "privacy.spoof_english" = 1;

        "privacy.firstparty.isolate" = true;
        "network.cookie.cookieBehavior" = 5;
        "dom.battery.enabled" = false;

        "gfx.webrender.all" = true;
        "network.http.http3.enabled" = true;
        "network.socket.ip_addr_any.disabled" = true; # disallow bind to 0.0.0.0
      };
    };

    # TODO: add caya profile with extensions and settings
    profiles.default = rec {
      settings = {
        "zen.workspaces.continue-where-left-off" = true;
        "zen.workspaces.natural-scroll" = true;
        "zen.view.compact.hide-tabbar" = true;
        "zen.view.compact.hide-toolbar" = true;
        "zen.view.compact.animate-sidebar" = false;
        "zen.welcome-screen.seen" = true;
        "zen.urlbar.behavior" = "float";
      };

      # pinsForce = false;
      # pins = {
      #   "GitHub" = {
      #     id = "48e8a119-5a14-4826-9545-91c8e8dd3bf6";
      #     workspace = spaces."Development".id;
      #     url = "https://github.com";
      #     position = 101;
      #     isEssential = false;
      #   };
      # };

      # containersForce = true;
      # containers = {
      #   Shopping = {
      #     color = "yellow";
      #     icon = "dollar";
      #     id = 2;
      #   };
      # };

      # # TODO: add spaces pins and essentials
      # spacesForce = true;
      # spaces = {
      #   "Games" = {
      #     id = "572910e1-4468-4832-a869-0b3a93e2f165";
      #     icon = "🎭";
      #     position = 1000;
      #   };
      #   "Development" = {
      #     id = "ec287d7f-d910-4860-b400-513f269dee77";
      #     icon = "💌";
      #     position = 1001;
      #   };
      #   "Shopping" = {
      #     id = "2441acc9-79b1-4afb-b582-ee88ce554ec0";
      #     icon = "💸";
      #     container = containers."Shopping".id;
      #     position = 1002;
      #   };
      #   "Themes" = {
      #     id = "8ed24375-68d4-4d37-ab7e-b2e121f994c1";
      #     icon = "😫";
      #     position = 1003;
      #   };
      #   "Downloads" = {
      #     id = "8ed24375-68d4-4d37-ab7e-b2e121f994c1";
      #     icon = "😫";
      #     position = 1004;
      #   };
      # };
    };
  };
}
