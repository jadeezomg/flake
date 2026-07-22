let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "mini";
  description = "Mini — Minisforum MS-01 headless server";
  user = sharedNixOSUser;
  # Gates the local LLM chat stack module (`./services/llm` — shared base +
  # open-webui + the backend selected below). The generic `dotfiles.profiles.llm`
  # serving stack defaults off and is unused on mini.
  miniLlmHosting = true;
  # Local chat + embeddings via llama.cpp router (`./services/llm/llama-cpp.nix`).
  miniLlmServedName = "local-chat";
  miniLlmEmbedServedName = "local-embed";
  miniLlmPort = 8000;
  # Tailnet bind: the firewall trusts only tailscale0 (modules/nixos/networking.nix),
  # so this is tailnet-only, never public. Loopback consumers still reach it.
  miniLlmHost = "0.0.0.0";
  # Beszel hub + agent (./services/beszel.nix): server/service/container monitoring.
  miniMonitoring = true;
  # Nixflix media stack (./services/media/): automation and playback on mini,
  # with library and download payloads mounted from Unraid.
  miniMediaHosting = true;
  # Static LAN address on enp2s0f0np0 (see default.nix mini-lan NM profile).
  miniLanAddress = "192.168.178.100";
  # Also serve Caddy vhosts on the LAN IP (same *.jadee.fyi names; needs local DNS).
  miniCaddyLanEnable = true;
  # GGML backends for nixpkgs `llama-cpp` (Vulkan + CLBlast/OpenCL only — not SYCL/OpenVINO).
  # Use `vulkan-opencl` to compile both, then pick GPU at runtime via `LLAMA_ARG_DEVICE` or
  # `systemctl edit llama-cpp-gemma` (see docs/hosts/mini-llm-hosting.md).
  miniLlamaCppGgmlBackends = "vulkan";
  # Optional `LLAMA_ARG_DEVICE` for llama-server (null = auto). List: `llama-server --list-devices`.
  miniLlamaCppDevice = null;
  # No guest accounts on a headless server.
  extraUsers = [ ];
  # 24 GiB RAM: keep local rebuild parallelism modest on a headless server.
  buildCores = 2;
  # Disabled until sbctl keys exist on the installed host. Flip to true in git
  # after `sudo sbctl create-keys`, then switch to let lanzaboote sign /boot.
  secureBoot = false;
  stateVersion = "26.05";
  # Note: mainMonitor / dmsSettingsFile / niriOutputsFile intentionally omitted.
  # the desktop profile (disabled here) carries the desktop HM tree.
}
