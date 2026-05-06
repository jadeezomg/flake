{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    devShells = {
      default = pkgs.mkShell {
        packages = [
          pkgs.alejandra
          pkgs.nil
          pkgs.nixd
          pkgs.nix-update
          pkgs.jq
          pkgs.curl
          pkgs.age
          pkgs.sops
        ];
      };

      claude-sandbox = let
        sandboxFloor = import ../lib/packages/sandbox-floor.nix pkgs;
        # minimal.nix minus Nix build / store clients — no nix(1), nh, nix-index in PATH
        nixBuildTools = with pkgs; [
          nh
          nix-index
          nix
        ];
        minimalPackages = pkgs.lib.subtractLists nixBuildTools (import ../lib/packages/minimal.nix pkgs);

        claude-sandboxed = inputs.agent-sandbox.lib.${system}.mkSandbox {
          pkg = pkgs.claude-code;
          binName = "claude";
          outName = "claude-sandboxed";

          # On Linux, agent-sandbox.nix bwraps with --tmpfs $HOME, then only stateDirs and
          # a few work paths are bind-mounted. The real ~/.config and ~/.nix are not
          # visible (ephemeral HOME); only $HOME paths listed in stateDirs/stateFiles
          # bridge through to the host.
          allowedPackages =
            sandboxFloor
            ++ minimalPackages
            ++ [
              pkgs.just
              pkgs.helix
              pkgs.nodejs
            ];

          stateDirs = ["$HOME/.claude"];
          stateFiles = [
            "$HOME/.claude.json"
            "$HOME/.claude.json.lock"
          ];

          extraEnv = {
            CLAUDE_CODE_OAUTH_TOKEN = "$CLAUDE_CODE_OAUTH_TOKEN";
            GITHUB_TOKEN = "$AGENT_PAT";
            GIT_AUTHOR_NAME = "claude";
            GIT_AUTHOR_EMAIL = "claude@localhost";
            GIT_COMMITTER_NAME = "claude";
            GIT_COMMITTER_EMAIL = "claude@localhost";
            EDITOR = "hx";
            VISUAL = "hx";
            PAGER = "bat";
            LC_ALL = "en_US.UTF-8";
            LANG = "en_US.UTF-8";
            NIX_PATH = "";
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
      in
        pkgs.mkShell {
          packages = [claude-sandboxed];
          shellHook = ''
            echo "claude-sandbox ready — invoke: claude-sandboxed --dangerously-skip-permissions"
          '';
        };
    };
  };
}
