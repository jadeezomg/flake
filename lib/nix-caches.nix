# Binary caches, shared by both platforms' Nix config:
#
# * NixOS  — `nix.settings.extra-substituters` (modules/shared/environment.nix)
# * Darwin — `determinateNix.customSettings` (modules/darwin/nix.nix)
#
# Darwin needs its own channel because Determinate Nix owns /etc/nix/nix.conf,
# which makes nix-darwin's `nix.settings` inert there (`nix.enable = false`).
#
# These two are the only places caches get declared. Do not also put them in
# flake.nix `nixConfig`: with the default `accept-flake-config = false`, Nix
# prompts once and then announces "Using saved setting for 'extra-substituters'
# … from ~/.local/share/nix/trusted-settings.json" on every single evaluation.
# Being in `trusted-users` does not suppress that. It was pure noise, because
# the settings below already apply system-wide.
#
# The one thing flake-level nixConfig bought was cache hits on a brand-new box,
# before any of this is active. Pass them on the command line for that first
# build instead:
#
#   --option extra-substituters https://cache.numtide.com \
#   --option extra-trusted-public-keys niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=
#
# `darwin = true` marks caches that actually serve aarch64-darwin. The
# compositor and kernel caches are Linux-only, and every substituter costs a
# lookup round trip per missing path, so they stay off macOS.
{
  caches = [
    {
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      # llm-agents.nix (claude-code, nono, hunk, omp, pi, hermes-agent) — the
      # reason this list has to reach macOS at all.
      darwin = true;
    }
    {
      url = "https://zed.cachix.org";
      key = "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU=";
      darwin = true;
    }
    {
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      darwin = true;
    }
    {
      url = "https://vicinae.cachix.org";
      key = "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=";
      darwin = true;
    }
    {
      url = "https://hyprland.cachix.org";
      key = "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=";
      darwin = false;
    }
    {
      url = "https://yazi.cachix.org";
      key = "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=";
      darwin = false;
    }
    {
      url = "https://niri.cachix.org";
      key = "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=";
      darwin = false;
    }
    {
      url = "https://noctalia.cachix.org";
      key = "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=";
      darwin = false;
    }
    {
      # CachyOS kernel (nix-cachyos-kernel)
      url = "https://attic.xuyh0120.win/lantian";
      key = "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=";
      darwin = false;
    }
    # mini host nightly cache-warming output — enable after `cachix create
    # jadee-flake` and replace the placeholder key.
    # {
    #   url = "https://jadee-flake.cachix.org";
    #   key = "jadee-flake.cachix.org-1:REPLACE_ME=";
    #   darwin = true;
    # }
  ];
}
