# Shared substrate for the local LLM chat stack, imported whenever `miniLlmHosting`
# regardless of `miniLlmBackend`. Holds what BOTH backends need so neither depends
# on the other being imported:
#   - the Intel GPU stack + dGPU probe (vLLM uses Level-Zero/OpenCL; llama.cpp uses
#     Vulkan — the dGPU must be probed either way),
#   - the Hugging Face Hub token (downloads + rate limits), shared by both services.
# The serving contract itself (served name / port / bind) lives in `host.nix` as
# `miniLlm{ServedName,Port,Host}` and is read by each backend module + the consumers.
{
  config,
  pkgs,
  ...
}: {
  # Intel discrete Arc / Xe graphics stack: OpenCL/L0 + media. vLLM-XPU needs the
  # compute runtime; llama.cpp's Vulkan path rides Mesa (from the base GPU profile)
  # but the extra packages are harmless when llama.cpp is the active backend.
  hardware.graphics.extraPackages = with pkgs; [
    intel-compute-runtime
    intel-compute-runtime.drivers
    intel-media-driver
    vpl-gpu-rt
  ];

  environment.systemPackages = [pkgs.intel-gpu-tools];

  # Battlemage-class discrete GPU: same probe as examples/brutus. Remove if you have
  # no dGPU. Needed by both backends — without it neither vLLM nor Vulkan sees the card.
  boot.kernelParams = ["xe.force_probe=e223"];

  # Hugging Face Hub auth (`secrets/secrets.yaml` → `hf_token`): rate limits + downloads.
  # Both `vllm-xpu` and `llama-cpp` load this env file (`EnvironmentFile` / `environmentFile`).
  sops.secrets.hf_token = {};
  sops.templates."mini-llm-hf.env" = {
    mode = "0400";
    content = ''
      HF_TOKEN=${config.sops.placeholder.hf_token}
      HUGGING_FACE_HUB_TOKEN=${config.sops.placeholder.hf_token}
    '';
  };
}
