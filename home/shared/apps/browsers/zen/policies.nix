{
  pkgs,
  lib,
  extensions,
  profileExtensions,
  ...
}: let
  mkLockedAttrs = builtins.mapAttrs (
    _: value: {
      Value = value;
      Status = "locked";
    }
  );
in {
  # Autofill
  AutofillAddressEnabled = true;
  AutofillCreditCardEnabled = false;
  OfferToSaveLogins = false;

  # Updates & Telemetry
  DisableAppUpdate = true;
  DisableFeedbackCommands = true;
  DisableFirefoxStudies = true;
  DisableTelemetry = true;

  # Tracking Protection
  EnableTrackingProtection = {
    Value = true;
    Locked = true;
    Cryptomining = true;
    Fingerprinting = true;
  };

  # Cleanup
  SanitizeOnShutdown = {
    FormData = true;
    Cache = true;
  };

  # Extensions
  ExtensionSettings = extensions.mkExtensionSettings (
    extensions.commonExtensions
    // profileExtensions
  );

  # Locked Preferences
  Preferences = mkLockedAttrs {
    # General
    "browser.aboutConfig.showWarning" = false;
    "browser.tabs.warnOnClose" = false;
    "browser.tabs.hoverPreview.enabled" = true;
    "browser.newtabpage.activity-stream.feeds.topsites" = false;
    "browser.topsites.contile.enabled" = false;
    "browser.translations.neverTranslateLanguages" = "de,en";

    # Media
    "media.videocontrols.picture-in-picture.video-toggle.enabled" = true;

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
}
