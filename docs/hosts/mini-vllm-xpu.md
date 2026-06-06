# Mini — Intel XPU vLLM (vllm-xpu-nix)

This mirrors the **Brutus** host setup under `~/.dotfiles/examples/dotfiles`:

- Flake input [`vllm-xpu-nix`](https://github.com/jasonboukheir/vllm-xpu-nix) (NixOS module `services.vllm-xpu.*`).
- `hosts/mini/vllm-xpu.nix` — same kernel package / instance layout as `examples/dotfiles/hosts/brutus/services/vllm-xpu.nix`, without the examples repo’s `homelab.ports` (ports are fixed `8000` / `8001` / `8002`).

Nix is configured with **`ca-derivations`** and **`dynamic-derivations`** (see `modules/shared/environment.nix`) so the vllm-xpu closure can evaluate, matching the note in `examples/dotfiles/modules/nixos/configuration.nix`.

## Hardware notes

- **`boot.kernelParams = ["xe.force_probe=e223"]`** matches Brutus (Intel Arc Battlemage–class dGPU). If mini has **only** integrated UHD and no discrete Arc card, remove that line or adjust the PCI ID after checking `lspci -nn`.
- **`intel-gpu-tools`** is installed for debugging (`intel_gpu_top`, etc.).

## llama-cpp vs vLLM

With vLLM enabled, **`dotfiles.profiles.devenv.llm.hosting`** is **`mkForce false`** on mini so the Vulkan **`llama-cpp`** package is not pulled for the same role. Re-enable hosting and disable vLLM if you prefer llama-cpp only.

## Further reading

Long-form tuning notes and image/matrix experiments live in the examples tree: `examples/dotfiles/docs/VLLM.md`.
