{
  description = "Devenv shell with opencode wrapped in agent-sandbox.nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sandbox.url = "github:archie-judd/agent-sandbox.nix";
    sandbox.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    sandbox,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      opencode-sandboxed = sandbox.lib.${system}.mkSandbox {
        pkg = pkgs.opencode;
        binName = "opencode";
        outName = "opencode-sandboxed";

        allowedPackages = with pkgs; [
          coreutils
          which
          findutils
          gnused
          gnugrep
          gnutar
          gzip
          curl
          jq
          git
          ripgrep
          fd
          bat
          eza
          delta
          just
          fzf
          nodejs
        ];

        # opencode keeps its config and auth under XDG_CONFIG_HOME/opencode.
        stateDirs = [
          "$HOME/.config/opencode"
          "$HOME/.local/share/opencode"
        ];

        extraEnv = {
          OPENROUTER_API_KEY = "$OPENROUTER_API_KEY";
          ANTHROPIC_API_KEY = "$ANTHROPIC_API_KEY";
          OPENAI_API_KEY = "$OPENAI_API_KEY";
          GITHUB_TOKEN = "$GITHUB_TOKEN";

          GIT_AUTHOR_NAME = "opencode";
          GIT_AUTHOR_EMAIL = "opencode@localhost";
          GIT_COMMITTER_NAME = "opencode";
          GIT_COMMITTER_EMAIL = "opencode@localhost";
        };

        restrictNetwork = true;
        allowedDomains = {
          "anthropic.com" = "*";
          "openai.com" = "*";
          "openrouter.ai" = "*";
          "raw.githubusercontent.com" = ["GET" "HEAD"];
          "objects.githubusercontent.com" = ["GET" "HEAD"];
          "api.github.com" = ["GET" "HEAD"];
          "registry.npmjs.org" = ["GET" "HEAD"];
        };
      };
    in {
      default = pkgs.mkShell {
        packages = [opencode-sandboxed];
        shellHook = ''
          echo "opencode-sandbox ready — invoke: opencode-sandboxed"
        '';
      };
    });
  };
}
