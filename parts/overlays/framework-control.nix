# framework-control is not in main nixpkgs yet; the framework-control flake ships it via a fork whose
# fetchFromGitHub hash for 0.5.2 went stale. We provide the package from packages/framework-control.
{lib, ...}: final: prev:
lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
  framework-control = final.callPackage ../../packages/framework-control/default.nix {};
}
