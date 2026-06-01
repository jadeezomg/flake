{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.llm.hosting;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optionals (!isDarwin) [
        # pkgs.vllm
        pkgs.llama-cpp
      ]
      ++ lib.optionals isDarwin [
        # Required by the HM unsloth-studio user service on Darwin.
        pkgs.podman
      ];
  };
}
