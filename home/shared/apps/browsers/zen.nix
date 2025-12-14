{
  inputs,
  config,
  ...
}:
let
  zenProfileSettings = {
    # --- Core Functionality ---
    "browser.shell.checkDefaultBrowser" = false;
    "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = true;
    "browser.aboutConfig.showWarning" = false;
    "browser.tabs.warnOnOpen" = false;

    # --- Privacy Settings ---
    "dom.security.https_only_mode" = true;
    "dom.security.https_only_mode_ever_enabled" = true;
    "privacy.donottrackheader.enabled" = true;
    "privacy.globalprivacycontrol.was_ever_enabled" = true;
    "network.dns.disablePrefetch" = true;
    "network.http.speculative-parallel-limit" = 0;
    "network.predictor.enabled" = false;
    "network.prefetch-next" = false;

    # --- Telemetry/tracking Disable ---
    "app.shield.optoutstudies.enabled" = false;
    "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
    "toolkit.telemetry.reportingpolicy.firstRun" = false;

    # --- Ui/ux Preferences ---
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

    # --- Zen Specific ---
    "zen.welcome-screen.seen" = true;
    "zen.themes.updated-value-observer" = true;

    # --- Download Settings ---
    "browser.download.lastDir" = "${config.home.homeDirectory}/downloads";
  };
in
{
  imports = [
    inputs.zen-browser.homeModules.twilight
  ];

  programs.zen-browser = {
    enable = true;
    profiles = {
      personal = {
        name = "Personal";
        isDefault = true;
        settings = zenProfileSettings;
        userChrome = "";
        extensions = [ ];
      };
    };

    policies =
      let
        mkExtensionSettings = builtins.mapAttrs (
          _: pluginId: {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
            installation_mode = "force_installed";
          }
        );
      in
      {
        DisableAppUpdate = true;
        DisableTelemetry = true;

        ExtensionSettings = mkExtensionSettings {
          "gdpr@cavi.au.dk" = "consent-o-matic";
          "addon@darkreader.org" = "darkreader";
          "78272b6fa58f4a1abaac99321d503a20@proton.me" = "proton-pass";
          "{91aa3897-2634-4a8a-9092-279db23a7689}" = "zen-internet";
        };
      };
  };
}
