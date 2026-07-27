# llm — the LLM serving stack (top-level profile, default off). Extracted
# from devenv: serving belongs to a host's role, not the dev toolbox. mini
# serves via its own llama-cpp host modules and keeps this off.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.llm;
  colibriEngine = pkgs.colibri.override {
    cudaSupport = cfg.llamaCppBackend == "cuda";
  };
  colibri =
    if cfg.colibri.autoTier then
      pkgs.runCommand "colibri-cli"
        {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          meta = colibriEngine.meta;
        }
        ''
          mkdir -p $out/bin
          makeWrapper ${lib.getExe colibriEngine} $out/bin/coli --add-flags --auto-tier
        ''
    else
      colibriEngine;
  llamaCpp =
    if
      cfg.llamaCppBackend == "cuda"
    # NVIDIA-only; builds from source (no public binary cache for CUDA).
    then
      pkgs.llama-cpp.override { cudaSupport = true; }
    # Vulkan works with Intel Arc / AMD / NVIDIA (Mesa or proprietary ICD).
    # Plain `llama-cpp` is CPU-only by default in nixpkgs.
    else
      pkgs.llama-cpp.override { vulkanSupport = true; };
in
{
  config = lib.mkIf cfg.enable {
    # Unsloth Studio user service (podman). Darwin has no systemd user service;
    # `just unsloth*` recipes drive podman there directly.
    home-manager.sharedModules = lib.optionals (!isDarwin) [ ./unsloth.nix ];

    environment.systemPackages =
      lib.optionals (!isDarwin) [
        llamaCpp
        pkgs.python314Packages.huggingface-hub
      ]
      ++ lib.optionals (!isDarwin && cfg.colibri.enable) [ colibri ]
      ++ lib.optionals isDarwin [
        # For the `just unsloth*` recipes (no systemd on darwin).
        pkgs.podman
      ];

    environment.variables = lib.mkMerge [
      (lib.mkIf (!isDarwin && cfg.colibri.enable && cfg.colibri.modelDir != null) {
        COLI_MODEL = cfg.colibri.modelDir;
      })
      (lib.mkIf (!isDarwin && cfg.colibri.enable && cfg.colibri.ramGb != null) {
        RAM_GB = toString cfg.colibri.ramGb;
      })
    ];
  };
}
