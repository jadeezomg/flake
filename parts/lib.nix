# Flake-level `lib` outputs — non-derivation values consumed by scripts.
{inputs, ...}: {
  flake.lib = {
    # Source tree for `just skills-upstream` (scripts/shell/skills-upstream.bash):
    # pinned by flake.lock, refreshed by `just update`.
    skillsUpstreamSrc = inputs.skills-mattpocock.outPath;
  };
}
