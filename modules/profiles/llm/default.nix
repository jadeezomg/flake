# llm: local LLM tooling and serving (top-level profile, default off).
#
# Two toggles under `dotfiles.profiles.llm`:
#   tools.enable  llama.cpp CLI, huggingface-hub CLI, unsloth-studio podman
#                 user service. For workstations.
#   serve.enable  the llama.cpp router server (./serve.nix, Linux only).
#                 mini turns it on in hosts/mini/services/llm/.
#
# The llama-cpp build follows the GPU trait (`dotfiles.hardware.gpu`) unless
# `llamaCppBackend` overrides it. Both toggles share `llamaCppPackage`.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.llm;

  derivedBackend =
    {
      nvidia = "cuda";
      intel = "vulkan";
      amd = "vulkan";
      none = "cpu";
    }
    .${config.dotfiles.hardware.gpu};
  backend = if cfg.llamaCppBackend != null then cfg.llamaCppBackend else derivedBackend;

  llamaCpp =
    {
      # NVIDIA only. Builds from source unless cache.nixos-cuda.org has it.
      cuda = pkgs.llama-cpp.override { cudaSupport = true; };
      # Works on Intel Arc, AMD, and NVIDIA through Mesa or the vendor ICD.
      vulkan = pkgs.llama-cpp.override { vulkanSupport = true; };
      # Plain nixpkgs `llama-cpp` is CPU only.
      cpu = pkgs.llama-cpp;
    }
    .${backend};
in
{
  imports = lib.optionals (!isDarwin) [ ./serve.nix ];

  config = lib.mkMerge [
    { dotfiles.profiles.llm.llamaCppPackage = lib.mkDefault llamaCpp; }

    (lib.mkIf cfg.tools.enable {
      # Unsloth Studio user service (podman). Darwin has no systemd user
      # services; the `just unsloth*` recipes drive podman there directly.
      home-manager.sharedModules = lib.optionals (!isDarwin) [ ./unsloth.nix ];

      environment.systemPackages =
        lib.optionals (!isDarwin) [
          cfg.llamaCppPackage
          pkgs.python314Packages.huggingface-hub
        ]
        ++ lib.optionals isDarwin [
          # For the `just unsloth*` recipes (no systemd on darwin).
          pkgs.podman
        ];
    })
  ];
}
