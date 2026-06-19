# Surface packages from external flake inputs that ship a `packages` output but
# no overlay, registering them as `pkgs.<name>` so consumer modules reference
# them like any local package (see ./local-packages.nix for the in-repo half).
{
  inputs,
  system,
}: _final: _prev: {
  hunk = inputs.hunk.packages.${system}.default;
}
