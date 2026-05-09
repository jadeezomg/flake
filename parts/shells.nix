{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    # Profile data lives in lib/nono-profiles.nix so the home-manager installer
    # (home/shared/development/tooling/nono-profiles.nix) and these devShells
    # render the same JSON.
    nonoProfileData = import ../lib/nono-profiles.nix;

    # Build a self-contained devShell that runs `<agentBin>` inside `nono`
    # using a profile from nonoProfileData. Self-contained = the profile is
    # rendered to a Nix store path; works without a home-manager switch.
    mkNonoShell = {
      profileName,
      agentPkg,
      agentBin,
      extraNotes ? "",
    }: let
      profileFile =
        pkgs.writeText "${profileName}.json"
        (builtins.toJSON nonoProfileData.${profileName});
      invocation = "nono run --profile ${profileFile} --allow-cwd --rollback -- ${agentBin}";
    in
      pkgs.mkShell {
        packages = [pkgs.nono agentPkg];
        shellHook = ''
          cat <<'EOF'
          nono-${agentBin} devShell

            First-time setup (once per host):
              nono setup

            Foreground (attached TUI):
              ${invocation}

            Detached, reattach later:
              nono run --detached --profile ${profileFile} --allow-cwd --rollback -- ${agentBin}
              nono ps
              nono attach <session>      # Ctrl-] d to detach again

            Inspect resolved capabilities:
              nono profile show ${profileFile}
          ${extraNotes}
          EOF
        '';
      };
  in {
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

      nono-claude = mkNonoShell {
        profileName = "claude-flake";
        agentPkg = pkgs.claude-code;
        agentBin = "claude";
        extraNotes = ''
          Credentials inherited from session env (sops). To upgrade to
          broker/proxy mode (key never enters sandbox), load it into the
          nono keystore and add `--credential anthropic` to the run.
        '';
      };

      nono-pi = mkNonoShell {
        profileName = "pi-flake";
        agentPkg = pkgs.pi-coding-agent;
        agentBin = "pi";
        extraNotes = ''
          Tighten egress after observing usage:
            nono why <denied-domain>           # diagnose a denial
            # then add --allow-domain <domain> to the profile in lib/nono-profiles.nix
        '';
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
