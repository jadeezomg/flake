{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    nixpkgs-stable = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

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

    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      # Do not override nixpkgs so CachyOS kernel version stays in sync with their builds
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.niri-unstable.url = "github:YaLTeR/niri/main";
    };

    # https://github.com/ozturkkl/framework-control — uses bundled nixpkgs fork for the package until upstream nixpkgs ships it
    framework-control = {
      url = "github:ozturkkl/framework-control";
    };

    google-workspace-cli = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}: let
    pkgsFuncs = import ./lib/pkgs.nix {inherit inputs;};
    inherit (pkgsFuncs) getPkgs;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./parts/hosts.nix
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
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
          kagi-ken-cli = import ./packages/kagi-ken-cli/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          kagi-ken = import ./packages/kagi-ken/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
          gws = inputs.google-workspace-cli.packages.${system}.default;
          workato-platform-cli = import ./packages/workato-platform-cli/default.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };
        };

        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.alejandra
            pkgs.nil
            pkgs.nixd
            pkgs.jq
            pkgs.curl
            pkgs.age
            pkgs.sops
          ];
        };
      };
    };
}
