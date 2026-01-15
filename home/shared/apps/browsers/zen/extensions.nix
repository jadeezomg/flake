{
  pkgs,
  lib,
  ...
}: let
  # Shared extension helper functions
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
  inherit mkPluginUrl mkExtensionEntry mkExtensionSettings;

  # Common extensions (shared across all profiles)
  commonExtensions = {
    "uBlock0@raymondhill.net" = "ublock-origin";
    "gdpr@cavi.au.dk" = "consent-o-matic";
    "addon@darkreader.org" = "darkreader";
    "{91aa3897-2634-4a8a-9092-279db23a7689}" = "zen-internet";
    "{74145f27-f039-47ce-a470-a662b129930a}" = "clearurls";
    "brave-search-extension@brave.com" = "bravesearch";
    "{135c3428-66bc-4b5b-9503-282dc00802e7}" = "toxcancel";
  };
}
