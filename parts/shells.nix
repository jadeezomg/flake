_: {
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      nonoAgents = import ../lib/nono-profiles.nix { inherit pkgs; };
      inherit (nonoAgents) metadata mkAgentInvocation mkAgentProfileFile;

      # Per-agent git identity is injected in the invocation because nono
      # profiles have no env-set field today; raw `nono run --profile <name>`
      # will not carry agent identity or the Co-authored-by hook.
      mkNonoShell =
        agentName: extraNotes:
        let
          meta = metadata.${agentName};
          profileFile = mkAgentProfileFile agentName;
          invocation = mkAgentInvocation {
            inherit agentName;
            usePackagePath = false;
          };
          detachedInvocation = mkAgentInvocation {
            inherit agentName;
            detached = true;
            usePackagePath = false;
          };
        in
        pkgs.mkShell {
          packages = [
            pkgs.llm-agents.nono
            meta.pkg
          ];
          shellHook = ''
            cat <<'EOF'
            nono-${meta.bin} devShell

              First-time setup (once per host):
                nono setup
                # Then `home-manager switch` populates libsecret with broker creds
                # (sops-keyring activation). Verify: secret-tool lookup service nono account context7_api_key

              Foreground (attached TUI):
                ${invocation}

              Detached, reattach later:
                ${detachedInvocation}
                nono ps
                nono attach <session>      # Ctrl-] d to detach again

              Inspect resolved capabilities:
                nono profile show ${profileFile}

              Identity injected as ${meta.gitName} <${meta.gitEmail}>; commits get
              Co-Authored-By: jadeezomg <github@jadee.fyi> via prepare-commit-msg.
            ${extraNotes}
            EOF
          '';
        };
    in
    {
      devShells = {
        default = pkgs.mkShell {
          packages = [
            pkgs.nixfmt-tree
            pkgs.nil
            pkgs.nixd
            pkgs.nix-update
            pkgs.jq
            pkgs.curl
            pkgs.age
            pkgs.sops
          ];
        };

        nono-claude = mkNonoShell "claude" ''
          Anthropic OAuth token persists in ~/.claude/.credentials.json
          (granted by base claude-code profile). Broker promotion deferred —
          see ADR-0001 future-work item 2.
        '';

        nono-pi = mkNonoShell "pi" ''
          OpenRouter, Context7, GitHub PAT injected via nono broker from
          libsecret. No LLM keys in pi's sandbox env.
        '';
      };
    };
}
