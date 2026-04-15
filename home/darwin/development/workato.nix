{pkgs, ...}: {
  home.packages = [
    (import ../../../packages/workato-platform-cli/default.nix {
      inherit pkgs;
      lib = pkgs.lib;
    })
  ];
}
