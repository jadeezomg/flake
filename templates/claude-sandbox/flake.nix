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
        # the sandbox itself. The list intentionally mirrors the
        # dotfiles.profiles.minimal CLI floor so aliases from the shell
        # core layer (cat=bat, find=fd, grep=rg, ls=eza) resolve if a human
        # ever enters an interactive shell inside the sandbox for debugging.
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
          helix # EDITOR=hx from env/base.nix
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

          # Sandbox-safe env floor (matches home/shared/shells/env/data.nix
          # `base` — never includes FLAKE, NH_FLAKE, SOPS_EDITOR, or any
          # path that points at the dotfiles repo).
          EDITOR = "hx";
          VISUAL = "hx";
          PAGER = "bat";
          LC_ALL = "en_US.UTF-8";
          LANG = "en_US.UTF-8";
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
