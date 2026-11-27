# APM copies each local `path:` skill into ~/.apm/apm_modules/_local twice in
# one `apm update -g` run. The copy keeps the source modes (`shutil.copystat`),
# so a skill from the read-only Nix store gets 0555 folders. Before the second
# copy, APM removes the first one. It cannot delete the files in a 0555
# subfolder, and its error handler (`_on_readonly_retry`) then sets the skill
# folder to 0200. The rollback calls `os.open(path)` without flags, and the run
# stops with "open() missing required argument 'flags' (pos 2)". APM then
# never writes its lock, so a changed skill never reaches ~/.claude/skills.
# Only skills with a subfolder fail (orchestrate, dotfiles-tools).
# `fixLocalCopyPerms` in modules/profiles/devenv/agents/apm.nix runs before
# APM, so it cannot reach a copy that APM makes during the run.
#
# This patch makes APM keep each copied folder owner-writable.
# Verified needed 2026-11-27 with apm 0.38.1 (Python 3.14) on aarch64-darwin,
# in a scratch HOME: two runs with this change passed. Without it, runs failed
# or left unreadable copies that break the next run.
{ expiry, lib }:
_final: prev: {
  llm-agents = prev.llm-agents // {
    apm =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.llm-agents.apm.version "0.42";
          reason = "apm reached 0.42 (patch verified needed at 0.38.1); check whether apm_cli/install/phases/local_content.py still copies folder modes from a read-only source, and drop this overlay if not.";
        }
        (
          prev.llm-agents.apm.overridePythonAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/apm_cli/install/phases/local_content.py \
                --replace-fail "shutil.copystat(resolved, dst_entry)" \
                  "shutil.copystat(resolved, dst_entry); dst_entry.chmod(dst_entry.stat().st_mode & 0o7777 | 0o700)" \
                --replace-fail "shutil.copystat(entry, dst_entry)" \
                  "shutil.copystat(entry, dst_entry); dst_entry.chmod(dst_entry.stat().st_mode & 0o7777 | 0o700)"
            '';
          })
        );
  };
}
