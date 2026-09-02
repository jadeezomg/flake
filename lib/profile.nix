# mkProfile: the shape that most profile leaves share. A leaf reads
# `dotfiles.profiles.<path>.enable` and, when it is on, installs packages and
# pushes Home Manager modules. Anything else for the same gate goes in `extra`.
#
# A leaf applies it to its own module arguments:
#
#   { dotfilesLib, ... }@args:
#   dotfilesLib.mkProfile {
#     path = [ "devenv" ];
#     packages = pkgs: [ pkgs.awscli2 ];
#   } args
#
# The result is the leaf's own module body, so definition order in merged
# lists (environment.systemPackages) is the same as with a hand-written
# `config = lib.mkIf cfg.enable { ... }`. Wrapping the result in `imports`
# would move it one level deeper and change that order.
#
# `packages`, `linuxPackages`, and `darwinPackages` are functions of pkgs.
# `linuxPackages` and `darwinPackages` replace the `lib.optionals (!isDarwin)`
# gates on package lists. They do not gate options: a leaf whose option
# namespace only exists on one platform still needs an import-level gate
# (see .agents/skills/module-structure/SKILL.md).
{
  path,
  packages ? (_: [ ]),
  linuxPackages ? (_: [ ]),
  darwinPackages ? (_: [ ]),
  hm ? [ ],
  extra ? { },
  imports ? [ ],
}:
{
  config,
  isDarwin ? false,
  lib,
  ...
}@args:
let
  # The leaf only declares `dotfilesLib`, so the module system does not pass
  # `pkgs`. Read it the way the module system itself resolves it.
  pkgs = args.pkgs or config._module.args.pkgs;
  cfg = lib.getAttrFromPath (
    [
      "dotfiles"
      "profiles"
    ]
    ++ path
  ) config;
  platformPackages = if isDarwin then darwinPackages else linuxPackages;
in
{
  inherit imports;
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = packages pkgs ++ platformPackages pkgs;
        home-manager.sharedModules = hm;
      }
      extra
    ]
  );
}
