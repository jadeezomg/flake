# Darwin-only leaf of devenv: mise comes from Homebrew, not from nixpkgs.
# nixpkgs lags behind the mise releases: on 2026-10-22 it had 2026.10.3, and
# Homebrew had 2026.10.17. A repo can require a newer mise through
# `min_version` in its mise.toml, and every mise command there then stops.
# The work profile upgrades the brews at each switch
# (homebrew.onActivation.upgrade). NixOS hosts get no mise.
#
# home-manager's programs.mise writes no shell activation without a package, so
# this file writes it. It follows that module for mise 2026.9 and newer: the
# nushell code is made at shell start, so that it captures the PATH of the user.
{ dotfilesLib, lib, ... }@args:
let
  mise = "/opt/homebrew/bin/mise";
in
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  extra.homebrew = {
    # mkDefault so the work profile keeps ownership of `enable` on caya.
    enable = lib.mkDefault true;
    brews = [ "mise" ];
  };
  hm = [
    (
      { ... }:
      {
        programs = {
          # A shell that starts before Homebrew installed mise skips the hook.
          zsh.initContent = ''
            [[ -x ${mise} ]] && eval "$(${mise} activate zsh)"
          '';
          bash.initExtra = ''
            [[ -x ${mise} ]] && eval "$(${mise} activate bash)"
          '';
          # `use` needs the file while config.nu is parsed, so env.nu always
          # writes it, empty when mise is missing. The pid keeps two shells
          # that start at the same time apart.
          nushell = {
            extraEnv = ''
              mkdir ($nu.cache-dir | path join "mise")
              let mise_file = ($nu.cache-dir | path join "mise" $"mise-($nu.pid).nu")
              if ("${mise}" | path exists) {
                ^${mise} activate nu | save $mise_file --force
              } else {
                "" | save $mise_file --force
              }
            '';
            extraConfig = ''
              use ($nu.cache-dir | path join "mise" $"mise-($nu.pid).nu")
              rm ($nu.cache-dir | path join "mise" $"mise-($nu.pid).nu")
            '';
          };
        };
      }
    )
  ];
} args
