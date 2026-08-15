# Pre-commit hook for this flake's own checkout.
#
# treefmt writes to the working tree, but git commits the index. A hook that
# only formats therefore leaves the unformatted content in the commit and a
# dirty tree behind. The `git add` at the end is what makes the formatting
# actually land in the commit.
#
# Scoped to the flake repo through an `includeIf gitdir:` condition, so every
# other repo keeps its own hooks. `core.hooksPath` points into the store, so the
# hook is read-only and is replaced on switch rather than edited in place.
{
  config,
  pkgs,
  ...
}:
let
  preCommit = pkgs.writeShellApplication {
    name = "pre-commit";
    # Prepended to PATH, so the ambient git still wins for git itself.
    runtimeInputs = [ pkgs.nixfmt-tree ];
    text = ''
      # Staged .nix files only. `-z` with `mapfile -d ""` keeps paths that
      # contain spaces intact. ACMR skips deletions, which treefmt cannot format.
      mapfile -d "" files < <(git diff --cached --name-only --diff-filter=ACMR -z -- '*.nix')

      # Plain `if`, not `[[ ... ]] && exit 0`: under `set -e` the latter exits 1
      # when no .nix files are staged, which would block every other commit.
      if [[ ''${#files[@]} -eq 0 ]]; then
        exit 0
      fi

      # --no-cache: treefmt's cache keys on mtime and size, so a revert followed
      # by a re-stage can be skipped. The staged file count is small.
      treefmt --quiet --no-cache -- "''${files[@]}"
      git add -- "''${files[@]}"
    '';
  };
in
{
  programs.git.includes = [
    {
      # Trailing slash: `gitdir:` matches the directory and everything below it.
      condition = "gitdir:${config.dotfiles.flakeRoot}/";
      # writeShellApplication puts the single script at $out/bin/pre-commit, and
      # git resolves hooks by name under hooksPath, so $out/bin is the hooks dir.
      contents.core.hooksPath = "${preCommit}/bin";
    }
  ];
}
