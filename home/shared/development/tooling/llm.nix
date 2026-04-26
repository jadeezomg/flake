{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;
  hostingEnabled = osConfig.dotfiles.profiles.devenv.llm.hosting.enable or false;
  agentSkillsDir = ../../../../agent-skills;
  agentSkillNames =
    lib.attrNames
    (lib.filterAttrs (_: type: type == "directory") (builtins.readDir agentSkillsDir));
  agentSkillFiles = lib.listToAttrs (lib.concatMap (skillName: let
      sourcePath = "${agentSkillsDir}/${skillName}";
    in [
      {
        name = ".claude/skills/${skillName}";
        value = {
          source = sourcePath;
          recursive = true;
        };
      }
      {
        name = ".cursor/skills/${skillName}";
        value = {
          source = sourcePath;
          recursive = true;
        };
      }
    ])
    agentSkillNames);
  unslothDefaults = {
    containerName = "unsloth-studio";
    jupyterPassword = "unsloth";
    workdir = "%h/.local/share/unsloth/work";
    studioPort = "8888";
    apiPort = "8000";
    sshPort = "2222";
    enableGpu = "auto";
  };
  unslothServiceEnvironment = [
    "UNSLOTH_CONTAINER_NAME=${unslothDefaults.containerName}"
    "UNSLOTH_JUPYTER_PASSWORD=${unslothDefaults.jupyterPassword}"
    "UNSLOTH_WORKDIR=${unslothDefaults.workdir}"
    "UNSLOTH_STUDIO_PORT=${unslothDefaults.studioPort}"
    "UNSLOTH_API_PORT=${unslothDefaults.apiPort}"
    "UNSLOTH_SSH_PORT=${unslothDefaults.sshPort}"
    "UNSLOTH_ENABLE_GPU=${unslothDefaults.enableGpu}"
  ];
  unslothServiceScript = pkgs.writeShellScript "unsloth-studio-service" ''
    set -euo pipefail

    container_name="''${UNSLOTH_CONTAINER_NAME:-${unslothDefaults.containerName}}"
    password="''${UNSLOTH_JUPYTER_PASSWORD:-${unslothDefaults.jupyterPassword}}"
    workdir="''${UNSLOTH_WORKDIR:-$HOME/.local/share/unsloth/work}"
    studio_port="''${UNSLOTH_STUDIO_PORT:-${unslothDefaults.studioPort}}"
    api_port="''${UNSLOTH_API_PORT:-${unslothDefaults.apiPort}}"
    ssh_port="''${UNSLOTH_SSH_PORT:-${unslothDefaults.sshPort}}"
    enable_gpu="''${UNSLOTH_ENABLE_GPU:-${unslothDefaults.enableGpu}}"
    is_linux="${
      if pkgs.stdenv.isLinux
      then "1"
      else "0"
    }"

    mkdir -p "$workdir"

    if ${pkgs.podman}/bin/podman container exists "$container_name"; then
      exec ${pkgs.podman}/bin/podman start -a "$container_name"
    fi

    gpu_args=()
    if [[ "$is_linux" == "1" && "$enable_gpu" != "false" ]]; then
      gpu_args+=(--gpus all)
    fi

    exec ${pkgs.podman}/bin/podman run --name "$container_name" \
      -e "JUPYTER_PASSWORD=$password" \
      -p "$studio_port:8888" \
      -p "$api_port:8000" \
      -p "$ssh_port:22" \
      -v "$workdir:/workspace/work" \
      "''${gpu_args[@]}" \
      unsloth/unsloth
  '';
in
  lib.mkMerge [
    (lib.mkIf agentsEnabled {
      home.file = agentSkillFiles;
    })

    (lib.mkIf hostingEnabled {
      systemd.user.services.unsloth-studio = {
        Unit = {
          Description = "Unsloth Studio container (Podman)";
          After = ["network-online.target"];
          Wants = ["network-online.target"];
        };
        Service = {
          Type = "simple";
          Environment = unslothServiceEnvironment;
          ExecStart = "${unslothServiceScript}";
          ExecStop = "${pkgs.podman}/bin/podman stop -t 15 ${unslothDefaults.containerName}";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })
  ]
