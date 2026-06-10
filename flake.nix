{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    # --- nixpkgs channels ---
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

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
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- desktop / UI ---
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
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
    framework-control.url = "github:ozturkkl/framework-control";
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

    # Intel XPU vLLM — add `nixosModules.default` + overlay (see upstream
    # https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md ).
    # `hosts/mini/vllm-xpu.nix` holds mini-only `services.vllm-xpu` + hardware/ccache/sops.
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

  outputs = inputs @ {flake-parts, ...}: let
    pkgsFuncs = import ./lib/pkgs.nix {inherit inputs;};
    inherit (pkgsFuncs) getPkgs;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./parts/hosts.nix
        ./parts/shells.nix
      ];

      systems = [
        "x86_64-linux"
        # "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = {
        pkgs,
        system,
        ...
      }: {
        _module.args.pkgs = getPkgs system [];

        packages = {
          iosevka-aile = import ./packages/iosevka-aile/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          iosevka-etoile = import ./packages/iosevka-etoile/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          context7 = import ./packages/context7/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          kagi-cli = import ./packages/kagi-cli/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          workato-platform-cli = import ./packages/workato-platform-cli/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          pi-coding-agent = import ./packages/pi-coding-agent/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
        };

        checks.mcp-servers = let
          testPassed = import ./tests/mcp-servers.nix {lib = pkgs.lib;};
        in
          assert testPassed;
            pkgs.runCommand "mcp-servers-tests" {} ''
              touch "$out"
            '';

        formatter = pkgs.alejandra;
      };
    };
}
