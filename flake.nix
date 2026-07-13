{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    # --- nixpkgs channels ---
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Shared by inputs that otherwise evaluate nix-systems/default, which still
    # includes x86_64-darwin. nixpkgs 26.11 dropped Intel macOS support.
    systems = {
      url = "path:./lib/systems.nix";
      flake = false;
    };
    # Pinned for zed-editor 1.8.2 on darwin: 1.9.0 fails to build on Hydra.
    # Rev is from the last green aarch64-darwin build, hydra.nixos.org/build/333610316.
    # Drop this (and parts/overlays/zed-pinned-darwin.nix) once zed-editor builds again.
    nixpkgs-zed.url = "github:NixOS/nixpkgs/9c4c05a947a91dc14625265fab505fb695e93218";

    # --- core infrastructure ---
    flake-parts.url = "github:hercules-ci/flake-parts";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # --- system modules ---
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- desktop / UI ---
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    vicinae.url = "github:vicinaehq/vicinae";
    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        vicinae.follows = "vicinae";
      };
    };

    # --- macOS / Homebrew ---
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-xykong-tap = {
      url = "github:xykong/homebrew-tap";
      flake = false;
    };

    # --- hardware ---
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    corecycler.url = "github:Daaboulex/linux-corecycler";

    # --- AI / agents ---
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    skills-mattpocock = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    # TUI code-review tool for AI-generated diffs (not in nixpkgs). Surfaced as
    # `pkgs.hunk` by parts/overlays/flake-packages.nix. Built via bun2nix; cached
    # at nix-community.cachix.org (already a trusted substituter).
    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.bun2nix.inputs.systems.follows = "systems";
    };

    # Intel XPU vLLM — add `nixosModules.default` + overlay (see upstream
    # https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md ).
    # `hosts/mini/services/llm/` holds the mini-only chat stack (`services.vllm-xpu` + hardware/ccache/sops).
    vllm-xpu-nix = {
      url = "github:jasonboukheir/vllm-xpu-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # Upstream lock uses a bare `git` fetch; Nix may shallow-clone first, then warn
        # `rejected … because shallow roots are not allowed to be updated` and re-fetch.
        # That dance can interact badly with `--dry-run` / substituters (missing `.drv`).
        vllm-xpu-kernels-unstable-src = {
          type = "git";
          url = "https://github.com/jasonboukheir/vllm-xpu-kernels.git";
          submodules = true;
          shallow = false;
        };
      };
    };
  };

  outputs =
    inputs@{
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./parts/hosts.nix
        ./parts/shells.nix
        ./parts/packages.nix
        ./parts/checks.nix
      ];

      systems = import systems;
    };
}
