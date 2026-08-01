# tuicr git integration (`pkgs.llm-agents.tuicr`, installed by ./default.nix).
#
# tuicr is a standalone review TUI, not a stdin pager and not a
# `$LOCAL $REMOTE` difftool — it opens the repo itself and takes `-r`/`-w`/`-p`.
# So it cannot occupy `core.pager` or `diff.tool`; an alias is the whole
# integration surface. The gh half is the `prdiff` alias in ../gh/config.yml.
#
# The `cd ${GIT_PREFIX:-.}` dance undoes git's habit of running `!` aliases from
# the repo root: tuicr resolves `-p` and `-A` against the cwd, so `git review -p
# .` from a subdirectory has to mean that subdirectory.
#
# `--no-update-check` because the flake pins the version; the startup probe is
# a network round trip that can never lead to an upgrade here.
{
  programs.git.settings.alias = {
    review = ''!f() { cd "''${GIT_PREFIX:-.}" && exec tuicr --no-update-check "$@"; }; f'';
    rv = "!git review";
  };
}
