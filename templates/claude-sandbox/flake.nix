{
  description = "Devenv shell with claude-code wrapped in agent-sandbox.nix";

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

      claude-sandboxed = sandbox.lib.${system}.mkSandbox {
        pkg = pkgs.claude-code;
        binName = "claude";
        outName = "claude-sandboxed";

        # Tools the agent is allowed to invoke. bash + cacert are added by
        # the sandbox itself; everything else is opt-in.
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

        # Persisted across runs so /login state survives.
        stateDirs = ["$HOME/.claude"];
        stateFiles = [
          "$HOME/.claude.json"
          "$HOME/.claude.json.lock"
        ];

        extraEnv = {
          # Tokens are evaluated at runtime — they never enter the Nix store.
          CLAUDE_CODE_OAUTH_TOKEN = "$CLAUDE_CODE_OAUTH_TOKEN";
          GITHUB_TOKEN = "$GITHUB_TOKEN";

          # Distinct git identity so the agent's commits are obvious.
          GIT_AUTHOR_NAME = "claude";
          GIT_AUTHOR_EMAIL = "claude@localhost";
          GIT_COMMITTER_NAME = "claude";
          GIT_COMMITTER_EMAIL = "claude@localhost";
        };

        restrictNetwork = true;
        allowedDomains = {
          "anthropic.com" = "*";
          "claude.com" = "*";
          "statsig.anthropic.com" = "*";
          "raw.githubusercontent.com" = ["GET" "HEAD"];
          "objects.githubusercontent.com" = ["GET" "HEAD"];
          "api.github.com" = ["GET" "HEAD"];
          "registry.npmjs.org" = ["GET" "HEAD"];
        };
      };
    in {
      default = pkgs.mkShell {
        packages = [claude-sandboxed];
        shellHook = ''
          echo "claude-sandbox ready — invoke: claude-sandboxed --dangerously-skip-permissions"
        '';
      };
    });
  };
}
