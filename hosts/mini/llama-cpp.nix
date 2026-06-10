# llama.cpp Vulkan — OpenAI-compatible GGUF API (additive to vLLM-XPU in ./vllm-xpu.nix).
# Imported only when `host.miniLlamaCppGemma` (see `hosts/mini/default.nix`).
# Model: https://huggingface.co/unsloth/gemma-4-12b-it-GGUF — see docs/hosts/mini-llm-hosting.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  llamaCpp = pkgs.llama-cpp.override {vulkanSupport = true;};

  modelRepo = "unsloth/gemma-4-12b-it-GGUF";
  modelQuant = "Q4_K_M";
  servedName = "gemma-4-12b-it";
  # 8000/8001/8002 are reserved for vLLM-XPU (./vllm-xpu.nix).
  port = 8010;
  host = "127.0.0.1";
  contextSize = 32768;
  gpuLayers = 999;
  hfHome = "${stateDir}/huggingface";
  stateDir = "/var/lib/llama-cpp";

  serveArgs = [
    "${llamaCpp}/bin/llama-server"
    "--hf-repo"
    "${modelRepo}:${modelQuant}"
    "--alias"
    servedName
    "--host"
    host
    "--port"
    (toString port)
    "--ctx-size"
    (toString contextSize)
    "--n-gpu-layers"
    (toString gpuLayers)
    "--threads"
    "8"
    "--parallel"
    "4"
    "--flash-attn"
    "on"
    "--jinja"
  ];
in {
  environment.systemPackages = [llamaCpp];

  users.users.llama = {
    isSystemUser = true;
    group = "llama";
    home = stateDir;
    createHome = false;
    extraGroups = [
      "render"
      "video"
    ];
  };
  users.groups.llama = {};

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 llama llama - -"
    "d ${hfHome} 0750 llama llama - -"
  ];

  systemd.services.llama-cpp-gemma = {
    description = "llama.cpp — ${servedName} (${modelRepo}:${modelQuant})";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    environment = {
      HF_HOME = hfHome;
    };

    serviceConfig = {
      Type = "simple";
      User = "llama";
      Group = "llama";

      ExecStart = lib.escapeShellArgs serveArgs;

      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = 0;

      DeviceAllow = ["char-drm rw"];
      PrivateDevices = false;

      WorkingDirectory = stateDir;

      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      ReadWritePaths = [stateDir];

      # Same HF token as vLLM (`hosts/mini/vllm-xpu.nix` → `sops.templates.mini-llm-hf.env`).
      EnvironmentFile = config.sops.templates."mini-llm-hf.env".path;
    };
  };
}
