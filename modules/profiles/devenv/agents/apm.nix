# APM (Agent Package Manager) deploys the local skills and registers MCP servers.
# Upstream skill bundles are Claude Code plugins (see `manifest` below).
#
# Replaces the former `lib/agent-skills.nix` + `skills.nix` (pinned flake
# inputs, local overrides, `.upstream-ignore`) and the three per-agent MCP
# activation modules. APM resolves, fetches, and deploys; this module only
# renders the manifest and runs `apm install -g` on switch.
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

  flakeRoot = config.dotfiles.flakeRoot;
  localSkillsDir = "${dotfilesLib.agentSkillsDir}/local";

  # Every directory under `local/` is a skill. APM names a skill after its
  # *directory*, not the frontmatter `name`.
  localSkills = lib.attrNames (
    lib.filterAttrs (_name: type: type == "directory") (builtins.readDir localSkillsDir)
  );

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
    targets = [ "claude" ];
    dependencies = {
      # Only the local skills. Upstream skill bundles (mattpocock, ponytail,
      # SimpleEnglish) are Claude Code plugins, declared in
      # data/agents/global/settings.json under `extraKnownMarketplaces` and
      # `enabledPlugins`. Plugins are Claude-only; APM stays for the local
      # skills and the MCP servers, which other agents read from Claude's config.
      apm = map (name: { path = "${localSkillsDir}/${name}"; }) localSkills;

      # omp and Zed's ACP agents read Claude's config, so the `claude` target
      # covers them. Remote endpoints authenticate interactively per client
      # (OAuth on first use) — nothing to install, no secret to wire.
      mcp = [
        (mkHttpServer "openwork" "https://api.openworklabs.com/mcp/agent")
        (mkStdioServer "context7-mcp")
      ]
      # mcp-nixos pulls python3.lupa → luajit_2_0, unsupported on
      # aarch64-darwin; ./default.nix omits the package there too.
      ++ lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) (mkStdioServer "mcp-nixos")
      ++ lib.optional workEnabled (mkHttpServer "linear" "https://mcp.linear.app/mcp");
    };
  };

  manifestFile = (pkgs.formats.yaml { }).generate "apm.yml" manifest;

  # APM copies `path:` deps into ~/.apm/apm_modules/_local with `copystat`, so
  # a dep from the read-only Nix store lands as mode 0555. When APM later
  # refreshes that copy, `rmtree` fails on the read-only tree and its onerror
  # hook runs `chmod(path, stat.S_IWRITE)`, which on Linux leaves mode 0200:
  # write-only, unreadable. Every later `apm install -g` then dies with
  # "Permission denied" before it deploys anything to ~/.claude/skills. The
  # deployed copies under ~/.claude/skills/<local skill> carry the same mode
  # and fail the same way on refresh.
  # Verified 2026-09-03 with apm 0.29.0 (utils/file_ops.py `_on_readonly_retry`).
  # Make both copies owner-writable and readable before each install.
  fixLocalCopyPerms =
    (dotfilesLib.expiry { inherit lib; } "modules/profiles/devenv/agents/apm.nix").recheckWhen
      {
        stale = lib.versionAtLeast apm.version "0.32";
        reason = "apm reached 0.32 (chmod workaround verified needed at 0.29.0); check whether _on_readonly_retry still uses S_IWRITE alone and drop fixLocalCopyPerms if fixed.";
      }
      ''
        for d in "$HOME/.apm/apm_modules/_local" ${
          lib.concatMapStringsSep " " (name: ''"$HOME/.claude/skills/${name}"'') localSkills
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
      # Non-fatal: `apm install` needs network, and a failed switch must not be
      # the cost of being offline. The next switch retries.
      apmInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${fixLocalCopyPerms}
        $DRY_RUN_CMD ${apm}/bin/apm install -g \
          || echo "apm: install -g failed (will retry next switch)"
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
