# llama.cpp Vulkan — the "llamacpp" backend of the local chat stack (selected via
# `host.miniLlmBackend = "llamacpp"` in `host.nix`; the "vllm" alternative is
# `./vllm-xpu.nix`). Exactly one backend runs at a time, and both bind the SAME
# contract (`host.miniLlm{ServedName,Port,Host}`) so consumers can't tell them apart.
# Shared GPU stack + HF token: `./default.nix`.
# Model: https://huggingface.co/unsloth/gemma-4-12b-it-GGUF — see docs/hosts/mini-llm-hosting.md.
{
  config,
  lib,
  pkgs,
  host,
  ...
}: let
  llamaCpp = pkgs.llama-cpp.override {vulkanSupport = true;};

  modelRepo = "unsloth/gemma-4-12b-it-GGUF";
  modelQuant = "Q4_K_M";
  # Shared serving contract (host.nix) — identical to the vLLM backend so consumers
  # (open-webui, honcho) never change. The served name is model-neutral on purpose.
  servedName = host.miniLlmServedName;
  port = host.miniLlmPort;
  listenHost = host.miniLlmHost;
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
    listenHost
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
