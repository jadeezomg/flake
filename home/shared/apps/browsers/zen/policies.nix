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

  ExtensionSettings = extensions.mkExtensionSettings (
    extensions.commonExtensions
    // profileExtensions
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
}
