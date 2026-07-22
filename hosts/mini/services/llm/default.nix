# Local LLM chat stack for mini — llama.cpp (Vulkan) router on :8000.
# Imported as a whole (gated by `host.miniLlmHosting`) from `hosts/mini/default.nix`.
#
# Aggregator + shared base: Intel GPU stack, HF token, open-webui frontend.
# Serving: `./llama-cpp.nix` — `local-chat` + `local-embed` on one port.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./open-webui.nix
    ./llama-cpp.nix
  ];

  # Intel discrete Arc / Xe graphics stack: OpenCL/L0 + media for Vulkan llama.cpp.
  hardware.graphics.extraPackages = with pkgs; [
    intel-compute-runtime
    intel-compute-runtime.drivers
    intel-media-driver
    vpl-gpu-rt
  ];

  environment.systemPackages = [ pkgs.intel-gpu-tools ];

  # Battlemage-class discrete GPU: same probe as examples/brutus.
  boot.kernelParams = [ "xe.force_probe=e223" ];

  # Hugging Face Hub auth (`secrets/secrets.yaml` → `hf_token`): rate limits + downloads.
  sops.secrets.hf_token = { };
  sops.templates."mini-llm-hf.env" = {
    mode = "0400";
    content = ''
      HF_TOKEN=${config.sops.placeholder.hf_token}
      HUGGING_FACE_HUB_TOKEN=${config.sops.placeholder.hf_token}
    '';
  };
}
