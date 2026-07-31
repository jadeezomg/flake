# `dotfilesLib` — the named channel for cross-tree data and helpers. Passed to
# every system and Home Manager module via specialArgs/extraSpecialArgs
# (parts/hosts.nix), so consumers never climb with `../../` imports.
#
# Functions are exposed unapplied; consumers apply their own pkgs/lib/etc.
# HM helpers that need `config` (mkLiveSymlink & friends) are NOT here — they
# live on `config.lib.dotfiles` (registered by ./home/dotfiles.nix).
let
  palette = import ./theme-palette.nix;
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

  # apply: { pkgs, pkgs-small }
  nonoProfiles = import ./nono-profiles.nix;
  # apply: { pkgs }
  hostStatus = import ./host-status.nix;
  # apply: { lib, osConfig ? null }
  mcpServers = import ./mcp-servers.nix;
  # apply: pkgs
  minimalPackages = import ./packages/minimal.nix;
  # apply: { lib, isDarwin }
  nixExperimentalFeatures = import ./nix-experimental-features.nix;
  expiry = import ./expiry.nix;

  # Binary caches for both platforms' Nix config; `darwin = true` marks the ones
  # that serve aarch64-darwin.
  nixCaches = (import ./nix-caches.nix).caches;

  sshDestinations = (import ../data/network/ssh-destinations.nix).destinations;
  agentSkillsDir = ../data/agents/skills;
  # apply: { lib, inputs }
  agentSkills = import ./agent-skills.nix;
  sopsFile = ../secrets/secrets.yaml;
}
