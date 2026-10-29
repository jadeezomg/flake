# APM (Agent Package Manager) deploys agent skills and registers MCP servers.
# Claude Code also gets the upstream skill bundles as plugins (see `manifest`).
#
# Replaces the former `lib/agent-skills.nix` + `skills.nix` (pinned flake
# inputs, local overrides, `.upstream-ignore`) and the three per-agent MCP
# activation modules. APM resolves, fetches, and deploys; this module only
# renders the manifest and runs `apm update -g` on switch.
#
# Why the manifest is generated instead of committed as plain YAML:
#   - local skills are enumerated from `dotfilesLib.agentSkillsDir`, so a new
#     directory under `local/` needs no second declaration. APM has no glob
#     for local deps.
#   - `path:` deps must be absolute. Relative paths resolve against the process
#     CWD, not the manifest, and a miss installs nothing *without an error*.
#   - `linear` is work-only and `mcp-nixos` is Linux-only. APM has no host
#     conditionals, so the gates have to live here.
#
# The rendered file lands read-only at ~/.apm/apm.yml, so ad-hoc
# `apm install <pkg>` fails by design: add new packages to `manifest` below.
# APM keeps its own lockfile at ~/.apm/apm.lock.yaml.
{
  config,
  dotfilesLib,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  apm = pkgs.llm-agents.apm;

  # Activation runs with a minimal PATH. APM and Claude Code both clone with
  # git, over HTTPS or SSH, and neither wrapper brings git or ssh.
  gitBinPath = lib.makeBinPath [
    pkgs.git
    pkgs.openssh
  ];

  # `claude plugin` commands fire the session hooks of settings.json (tuios,
  # herdr). Those hooks are for real sessions, and the activation PATH has no
  # tuios, so they only fail. A settings file turns them off for these runs.
  claudeNoHooks = pkgs.writeText "claude-no-hooks.json" (builtins.toJSON { disableAllHooks = true; });

  flakeRoot = config.dotfiles.flakeRoot;
  localSkillsDir = "${dotfilesLib.agentSkillsDir}/local";

  # Every directory under `local/` is a skill. APM names a skill after its
  # *directory*, not the frontmatter `name`.
  localSkills = lib.attrNames (
    lib.filterAttrs (_name: type: type == "directory") (builtins.readDir localSkillsDir)
  );

  tuicr = pkgs.llm-agents.tuicr;

  # tuicr's herdr launcher types `bash -c '<script>'` into the new pane and
  # escapes each ' in the script as '\''. nu, the pane shell here, has no such
  # escape, so the end marker never reaches the pane and the launcher waits
  # forever. The patch writes the script to a file and types `bash <file>`,
  # which every shell parses the same way. The script deletes its own file.
  tuicrSkill =
    (dotfilesLib.expiry { inherit lib; } "modules/profiles/devenv/agents/apm.nix").recheckWhen
      {
        stale = lib.versionAtLeast tuicr.version "0.31";
        reason = "tuicr reached 0.31 (nu patch written for 0.28.0); check whether skills/tuicr/tuicr-wrapper-herdr.sh still types `bash -c '...'` into the pane, and drop tuicrSkill's patch if the launcher works in nu.";
      }
      (
        pkgs.runCommand "tuicr-skill-${tuicr.version}" { } ''
          cp -r ${tuicr}/share/skills/tuicr/tuicr $out
          chmod -R u+w $out
          substituteInPlace $out/tuicr-wrapper-herdr.sh --replace-fail \
            ${lib.escapeShellArg ''pane_command="bash -c '$escaped_inner_script'"''} \
            ${lib.escapeShellArg (
              lib.concatStringsSep "\n  " [
                "script_file=$(mktemp /tmp/tuicr-run.XXXXXX)"
                ''printf '%s\n' 'rm -f -- "$0"' "$inner_script" >"$script_file"''
                ''pane_command="bash $script_file"''
              ]
            )}
        ''
      );

  # Skills that ship inside a Nix package. APM deploys them like the local
  # skills, and deploys them again when the package changes.
  packageSkills = {
    terminal-browser = "${pkgs.llm-agents.terminal-browser}/lib/terminal-browser/skills/default/terminal-browser";
    tuicr = "${tuicrSkill}";
  };

  # Name → store path of each skill that APM copies to both targets.
  storeSkills = lib.genAttrs localSkills (name: "${localSkillsDir}/${name}") // packageSkills;

  workEnabled = osConfig.dotfiles.profiles.work.enable or false;

  mkStdioServer = name: {
    inherit name;
    registry = false;
    transport = "stdio";
    command = name;
    args = [ ];
  };

  mkHttpServer = name: url: {
    inherit name url;
    registry = false;
    transport = "http";
  };

  manifest = {
    name = "jadee-global";
    version = "1.0.0";
    # `claude` → ~/.claude/skills (Claude Code). omp skips this folder
    # (skills.enableClaudeUser is off by default).
    # `agent-skills` → ~/.agents/skills (pi, omp).
    targets = [
      "claude"
      "agent-skills"
    ];
    dependencies = {
      # Upstream bundles go to `agent-skills` only. Claude Code gets them as
      # plugins (data/agents/global/settings.json), which run their hooks
      # themselves. For the `claude` target, APM writes package hooks into
      # ~/.claude/settings.json, which is a symlink into this repo.
      apm =
        lib.mapAttrsToList (_name: path: { inherit path; }) storeSkills
        ++ map (dep: dep // { targets = [ "agent-skills" ]; }) (
          [ { git = "AminBlg/SimpleEnglish"; } ]
          # Private repo: SSH, because the fine-grained GITHUB_TOKEN has no
          # access to the AMN-DATA org.
          ++ lib.optionals workEnabled (
            map
              (name: {
                git = "git@github.com:AMN-DATA/claude-plugin.git";
                path = "plugins/${name}";
              })
              [
                "caya-working-docs"
                "caya-customer-api"
                "caya-design-system"
                "caya-mailroom-api"
              ]
          )
        );

      # The `claude` target writes these into Claude's config, which Zed's
      # Claude ACP agent also reads. omp reads its own ~/.omp/agent/mcp.json,
      # which APM does not write. Remote endpoints authenticate interactively
      # per client (OAuth on first use) — nothing to install, no secret to wire.
      mcp = [
        (mkStdioServer "context7-mcp")
      ]
      # mcp-nixos pulls python3.lupa → luajit_2_0, unsupported on
      # aarch64-darwin; ./default.nix omits the package there too.
      ++ lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) (mkStdioServer "mcp-nixos")
      ++ lib.optional workEnabled (mkHttpServer "linear" "https://mcp.linear.app/mcp");
    };
  };

  manifestFile = (pkgs.formats.yaml { }).generate "apm.yml" manifest;

  claude = "${pkgs.llm-agents.claude-code}/bin/claude --settings ${claudeNoHooks}";

  # APM does not take over a ~/.claude.json entry that it did not write. An
  # entry with the name of a declared server, for example from before APM, makes
  # every switch fail ("conflicts with the existing claude connection"). Remove
  # such an entry, and APM adds its own copy in the same run. For these names,
  # the flake is the source of truth.
  adoptMcpServers = ''
    owned=$(${pkgs.yq-go}/bin/yq '.mcp_servers // [] | .[]' "$HOME/.apm/apm.lock.yaml" 2>/dev/null || true)
    for s in ${lib.escapeShellArgs (map (server: server.name) manifest.dependencies.mcp)}; do
      if ${pkgs.jq}/bin/jq -e --arg s "$s" '.mcpServers[$s]' "$HOME/.claude.json" >/dev/null 2>&1 \
        && ! ${pkgs.gnugrep}/bin/grep -qxF "$s" <<<"$owned"; then
        $DRY_RUN_CMD ${claude} mcp remove "$s" -s user >/dev/null \
          || echo "apm: could not remove the unmanaged MCP entry $s"
      fi
    done
  '';

  # APM copies `path:` deps into ~/.apm/apm_modules/_local with `copystat`, so
  # a dep from the read-only Nix store lands as mode 0555. When APM later
  # refreshes that copy, `rmtree` fails on the read-only tree and its onerror
  # hook runs `chmod(path, stat.S_IWRITE)`, which on Linux leaves mode 0200:
  # write-only, unreadable. Every later `apm install -g` then dies with
  # "Permission denied" before it deploys anything to ~/.claude/skills. The
  # deployed copies under ~/.claude/skills/<local skill> and
  # ~/.agents/skills/<local skill> carry the same mode and fail the same way on
  # refresh.
  # Verified 2026-09-03 with apm 0.29.0, re-verified 2026-09-27 with 0.32.0
  # (utils/file_ops.py `_on_readonly_retry`).
  # A read-only ~/.agents copy is worse: APM writes the new ~/.claude copy,
  # fails on ~/.agents, and does not write the lock. The next run then refuses
  # the ~/.claude files as "unmanaged". Verified 2026-10-29 with apm 0.35.0.
  # Make every copy owner-writable and readable before each install.
  fixLocalCopyPerms =
    (dotfilesLib.expiry { inherit lib; } "modules/profiles/devenv/agents/apm.nix").recheckWhen
      {
        stale = lib.versionAtLeast apm.version "0.36";
        reason = "apm reached 0.36 (chmod workaround verified needed at 0.32.0); check whether _on_readonly_retry still uses S_IWRITE alone and drop fixLocalCopyPerms if fixed.";
      }
      ''
        for d in "$HOME/.apm/apm_modules/_local" ${
          lib.concatMapStringsSep " " (
            name: ''"$HOME/.claude/skills/${name}" "$HOME/.agents/skills/${name}"''
          ) (lib.attrNames storeSkills)
        }; do
          if [ -d "$d" ]; then
            $DRY_RUN_CMD chmod -R u+rwX "$d"
          fi
        done
      '';
in
{
  home = {
    file.".apm/apm.yml".source = manifestFile;

    activation = {
      # `apm update` installs and also moves git deps to their latest refs.
      # Non-fatal: it needs network, and a failed switch must not be the cost
      # of being offline. The next switch retries. Runs after linkGeneration:
      # before it, ~/.apm/apm.yml still links to the previous generation's
      # manifest, and APM applies that one.
      apmInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${fixLocalCopyPerms}
        ${adoptMcpServers}
        PATH=${gitBinPath}:$PATH $DRY_RUN_CMD ${apm}/bin/apm update -g --yes \
          || echo "apm: update -g failed (will retry next switch)"
      '';

      # Upstream skills are Claude Code plugins (see `manifest`). The flake does
      # not pin them, so each switch on each host pulls the latest versions.
      # Runs after linkGeneration so that a marketplace that was just added to
      # settings.json is known. Skips `@synced` plugins: claude.ai manages them.
      # Skips `@inline` plugins: those are the mods from CLAUDE_CODE_PLUGIN_DIRS,
      # which load from the checkout and have no marketplace to update from.
      # Non-fatal for the same reason as apmInstall.
      claudePluginsUpdate = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        claude="${claude}"
        PATH=${gitBinPath}:$PATH $DRY_RUN_CMD $claude plugin marketplace update \
          || echo "claude: marketplace update failed (will retry next switch)"
        $claude plugin list --json 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.[].id | select(endswith("@synced") or endswith("@inline") | not)' \
          | while read -r p; do
              PATH=${gitBinPath}:$PATH $DRY_RUN_CMD $claude plugin update "$p" \
                || echo "claude: plugin update $p failed (will retry next switch)"
            done
      '';

      # Repo: .claude/skills → .agents/skills, so this flake's own project
      # skills stay visible. Unrelated to APM, carried over from skills.nix.
      linkFlakeProjectSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${flakeRoot}/.claude"
        $DRY_RUN_CMD ln -snf ../.agents/skills "${flakeRoot}/.claude/skills"
      '';
    };
  };
}
