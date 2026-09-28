# `dotfilesLib` — the named channel for cross-tree data and helpers. Passed to
# every system and Home Manager module via specialArgs/extraSpecialArgs
# (parts/hosts.nix), so consumers never climb with `../../` imports.
#
# Functions are exposed unapplied; consumers apply their own pkgs/lib/etc.
# HM helpers that need `config` (mkLiveSymlink & friends) are NOT here — they
# live on `config.lib.dotfiles` (registered by ./home/dotfiles.nix).
let
  palette = import ./theme-palette.nix;

  # Two address registries, kept apart on purpose so neither becomes a second
  # source of truth for the other:
  #   hostFacts — machines this flake BUILDS; owned by hosts/<name>/host.nix.
  #   lanHosts  — machines it only talks to (Unraid, ...), which have no host.nix.
  hostFacts = (import ../hosts/hosts.nix).hosts;
  lanHosts = (import ../data/network/lan-hosts.nix).hosts;

  inherit ((import ../data/users/users.nix)) users;
in
{
  # Birds-of-Paradise palette (Python mirror:
  # scripts/src/flake_scripts/lib/palette.py — keep both in sync).
  inherit palette;

  # The palette as a base16 scheme, for both halves of Stylix (HM and NixOS).
  themeBase16 = import ./theme-base16.nix { inherit palette; };

  # Font selections shared by Stylix, the fonts profile, and the GDM greeter's
  # dconf profile. apply: { pkgs }
  themeFonts = import ./theme-fonts.nix;

  # Shell env/path data shared by minimal's shells tree and essentials'
  # shell-system-env.
  shellEnvData = import ./shells/env-data.nix;
  shellPaths = import ./shells/paths.nix;

  # apply: { pkgs }
  nonoProfiles = import ./nono-profiles.nix;
  # apply: { pkgs }
  hostStatus = import ./host-status.nix;
  # apply: pkgs
  minimalPackages = import ./packages/minimal.nix;
  # apply: { lib, isDarwin }
  nixExperimentalFeatures = import ./nix-experimental-features.nix;
  expiry = import ./expiry.nix;
  # apply: { path, packages?, linuxPackages?, darwinPackages?, hm?, extra? }
  # Returns a system module for a plain profile leaf. See ./profile.nix.
  mkProfile = import ./profile.nix;

  # Binary caches for both platforms' Nix config; `darwin = true` marks the ones
  # that serve aarch64-darwin.
  nixCaches = (import ./nix-caches.nix).caches;

  # Interactive ssh aliases, derived entirely from the two registries above —
  # no hostname or address is written out a second time here.
  sshDestinations =
    (import ../data/network/ssh-destinations.nix {
      hosts = hostFacts;
      inherit lanHosts;
    }).destinations;

  # Addresses of machines the flake talks to but does not build (Unraid, ...).
  # Flake-managed hosts keep their facts in hosts/<name>/host.nix instead.
  inherit lanHosts;

  # The account registry from data/users/users.nix, keyed by registry name (not
  # by `username`). `hosts/lib.nix` builds the system accounts from the same
  # file; modules read identity facts (git author, ...) through this.
  inherit users;
  # Agent data. `data/agents/**` is spelled once here; consumers pick the form
  # they need. Store paths are immutable and need a switch to pick up an edit;
  # the live paths from `agentDataFiles` are the checkout itself, for files
  # that must stay editable (live symlinks).
  agentsDataDir = ../data/agents;
  # A store path, so APM's local `path:` deps do not depend on where the flake
  # is checked out — see modules/profiles/devenv/agents/apm.nix.
  agentSkillsDir = ../data/agents + "/skills";
  # apply: flakeRoot
  agentDataFiles = flakeRoot: rec {
    root = "${flakeRoot}/data/agents";
    globalAgentsMd = "${root}/global/AGENTS.md";
    claudeSettings = "${root}/global/settings.json";
    ompConfig = "${root}/omp/config.yml";
    ompTheme = "${root}/omp/themes/birds-of-paradise.json";
    localSkills = "${root}/skills/local";
  };
  sopsFile = ../secrets/secrets.yaml;
}
