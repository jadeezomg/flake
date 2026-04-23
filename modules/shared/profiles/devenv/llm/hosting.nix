{
  config,
  lib,
  pkgs-stable,
  isDarwin,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.llm.hosting;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optionals (!isDarwin) [
      pkgs-stable.vllm
    ];
  };
}
