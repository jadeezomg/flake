{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    # --- nixpkgs channels ---
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Pin skhd from a fixed nixpkgs rev: macOS keys skhd's Accessibility grant to
    # its exact store path, so nixpkgs bumps silently break the Vicinae
    # Option+Space hotkey until re-granted. Freezing the rev means the path (and
    # grant) only move on a deliberate bump here. Darwin-only overlay lives in
    # parts/overlays/skhd-pinned-darwin.nix. Bump rev + re-grant Accessibility together.
    nixpkgs-skhd.url = "github:NixOS/nixpkgs/61b7c44c4073f0b827768aff0049561b5110ea5a";
    # Shared by inputs that otherwise evaluate nix-systems/default, which still
    # includes x86_64-darwin. nixpkgs 26.11 dropped Intel macOS support.
    systems = {
      url = "path:./lib/systems.nix";
      flake = false;
    };
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
    nixflix = {
      url = "github:kiriwalawren/nixflix";
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
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    vicinae.url = "github:vicinaehq/vicinae";
    vicinae-extensions.url = "github:vicinaehq/extensions";
    # Declarative `services.flatpak.{remotes,packages}`; nixpkgs only ships the
    # daemon. Wired in modules/profiles/integrations.nix.
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";

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
    homebrew-nkzw-tap = {
      url = "github:nkzw-tech/homebrew-tap";
      flake = false;
    };

    # --- hardware ---
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    corecycler.url = "github:Daaboulex/linux-corecycler";

    # --- AI / agents ---
    llm-agents.url = "github:numtide/llm-agents.nix";
    hermes-agent.url = "github:NousResearch/hermes-agent";
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
