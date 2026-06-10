{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.python;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      uv # rustic Python package manager
      ty # rustic type checker
      ruff # Fast Python formatter/linter
      pipx # User-scoped pip applications

      (python3.withPackages (ps:
        with ps; [
          pip
          lz4
        ]))
    ];
  };
}
