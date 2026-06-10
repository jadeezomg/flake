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
        # Vulkan backend works with Intel Arc / AMD / NVIDIA (Mesa or proprietary
        # ICD). Plain `llama-cpp` is CPU-only by default in nixpkgs.
        (pkgs.llama-cpp.override {vulkanSupport = true;})
      ]
      ++ lib.optionals isDarwin [
        # Required by the HM unsloth-studio user service on Darwin.
        pkgs.podman
      ];
  };
}
