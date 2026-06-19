{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  hermesSrc = inputs.hermes-agent;
  haInputs = hermesSrc.inputs;

  staleNpmDepsHash = "sha256-m9cjbjzi4SaFCjODfdrawS5e+1ag+MpRn528/upSNqo=";
  realNpmDepsHash = "sha256-kbjJksq7limRIYqP3DwI+GNgCXkG96tXcsQqmuEedxo=";

  hermesSrcPatched = pkgs.runCommand "hermes-agent-src-npmhash-fix" {} ''
    cp -r ${hermesSrc} $out
    chmod -R +w $out
    substituteInPlace $out/nix/lib.nix \
      --replace-fail '${staleNpmDepsHash}' '${realNpmDepsHash}'
  '';

  hermesAgentFixed = pkgs.callPackage "${hermesSrcPatched}/nix/hermes-agent.nix" {
    inherit (haInputs) uv2nix pyproject-nix pyproject-build-systems;
    npm-lockfile-fix = haInputs.npm-lockfile-fix.packages.${system}.default;
    rev = hermesSrc.rev or null;
  };
in {
  services.hermes-agent = {
    enable = true;
    package = hermesAgentFixed;

    addToSystemPackages = true;
    restart = "always";
    restartSec = 5;

    extraPackages = [
      pkgs.kagi-cli
      pkgs.context7
    ];

    extraDependencyGroups = ["matrix" "web" "messaging" "mcp" "honcho" "edge-tts"];

    environment = {
      MATRIX_HOMESERVER = "http://127.0.0.1:6167";
      MATRIX_USER_ID = "@hermes:matrix.jadee.fyi";
      MATRIX_DEVICE_ID = "hermes-mini";
      MATRIX_E2EE_MODE = "optional";
    };

    environmentFiles = [config.sops.templates."hermes.env".path];
  };

  sops.secrets.openrouter_api_key = {};
  sops.secrets.agent_pat = {};
  sops.secrets.hf_token = {};
  sops.secrets.kagi_session_token.key = "kagi/session_token";
  sops.secrets.context7_api_key = {};
  sops.secrets.matrix_hermes_password.key = "matrix/hermes_password";
  sops.templates."hermes.env" = {
    mode = "0400";
    content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder.openrouter_api_key}
      GITHUB_TOKEN=${config.sops.placeholder.agent_pat}
      HF_TOKEN=${config.sops.placeholder.hf_token}
      KAGI_SESSION_TOKEN=${config.sops.placeholder.kagi_session_token}
      CONTEXT7_API_KEY=${config.sops.placeholder.context7_api_key}
      MATRIX_PASSWORD=${config.sops.placeholder.matrix_hermes_password}
    '';
  };

  systemd.services.hermes-agent.environment.HERMES_MANAGED = lib.mkForce "";
  system.activationScripts.hermes-unmanage = {
    deps = ["hermes-agent-setup"];
    text = ''
      _m="${config.services.hermes-agent.stateDir}/.hermes/.managed"
      [ -e "$_m" ] && ${pkgs.coreutils}/bin/unlink "$_m" || true
    '';
  };
}
