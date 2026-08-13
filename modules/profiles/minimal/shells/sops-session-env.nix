# Expose home-manager sops secrets to the user session environment so every
# process started by the user — GUI apps (Zed, niri-spawned apps on Linux;
# apps from Finder/Dock/Spotlight on Darwin) and shells alike — inherits
# them.
#
# Three delivery paths (same `exports` list):
#
#   Linux session (GUI apps, systemd-spawned children):
#     1. Write `~/.config/environment.d/50-sops-secrets.conf` (mode 0600).
#        systemd-environment-d-generator picks this up at user manager start.
#     2. `systemctl --user set-environment` for the live session.
#
#   Darwin session (GUI apps):
#     1. LaunchAgent `~/Library/LaunchAgents/org.nix-community.home.sops-session-env.plist`
#        runs a wrapper script at login (RunAtLoad=true) that calls
#        `launchctl setenv` for each secret.
#     2. The same wrapper script is invoked during home-manager activation so
#        the live session sees vars without a re-login.
#
#   Interactive shells (bash/zsh/fish/nushell):
#     Read decrypted secret files at startup. Terminals and tools like Cursor
#     do not inherit systemd user env on Niri, so shell init is required.
#
# Already-running processes don't pick up updates on either OS — restart them
# (Zed, terminals, etc.) after a switch.
#
# Each sops secret expands to one or more `exports` (var, path, optional
# `valuePrefix`). The default mapping is `foo-bar` → `FOO_BAR`. Fan-outs:
# - GitHub PAT → `GITHUB_TOKEN`, `GITHUB_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN`,
#   and `NIX_CONFIG=access-tokens = github.com=…`.
# - Hugging Face (`hf-token`) → `HF_TOKEN` and `HUGGING_FACE_HUB_TOKEN`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = config.sops.secrets or { };

  # Secrets delivered to consumers by another mechanism (not the session env).
  #
  # `kagi-*` are intentionally NOT excluded: they're also rendered into
  # ~/.kagi.toml (security.nix), but the kagi CLI only reads that file relative
  # to the cwd — so any process started outside $HOME (Claude Code, GUI apps)
  # can't find it. Exporting KAGI_API_KEY/KAGI_SESSION_TOKEN to the session env
  # makes kagi cwd-independent; env overrides the toml and the values match, so
  # there's no conflict.
  sessionEnvExcludeAttrs = [ ];
  secretNames = lib.filter (n: !lib.elem n sessionEnvExcludeAttrs) (lib.attrNames secrets);

  githubPatSecretAttrs = [
    "github-token"
    "gh-token"
  ];
  hfTokenSecretAttrs = [ "hf-token" ];

  resolvePath =
    name:
    let
      raw = secrets.${name}.path;
    in
    if lib.hasPrefix "/" raw then raw else "${config.home.homeDirectory}/${raw}";

  defaultEnvVar = name: lib.strings.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name);

  mkExports =
    name:
    let
      path = resolvePath name;
    in
    if lib.elem name githubPatSecretAttrs then
      [
        {
          inherit path;
          var = "GITHUB_TOKEN";
        }
        {
          inherit path;
          var = "GITHUB_PAT";
        }
        {
          inherit path;
          var = "GITHUB_PERSONAL_ACCESS_TOKEN";
        }
        {
          inherit path;
          var = "NIX_CONFIG";
          valuePrefix = "access-tokens = github.com=";
        }
      ]
    else if lib.elem name hfTokenSecretAttrs then
      [
        {
          inherit path;
          var = "HF_TOKEN";
        }
        {
          inherit path;
          var = "HUGGING_FACE_HUB_TOKEN";
        }
      ]
    else
      [
        {
          inherit path;
          var = defaultEnvVar name;
        }
      ];

  exports = lib.concatMap mkExports secretNames;

  esc = lib.escapeShellArg;
  prefixOf = e: e.valuePrefix or "";

  envDir = "${config.home.homeDirectory}/.config/environment.d";
  envFile = "${envDir}/50-sops-secrets.conf";

  emitLinux = e: ''
    if [ -r ${esc e.path} ]; then
      _val=${esc (prefixOf e)}"$(tr -d '[:space:]' <${esc e.path})"
      printf '%s=%s\n' ${esc e.var} "$_val" >>"$envFile"
      systemctl --user set-environment ${esc e.var}="$_val" 2>/dev/null || true
    fi
  '';

  emitDarwin = e: ''
    if [ -r ${esc e.path} ]; then
      _val=${esc (prefixOf e)}"$(tr -d '[:space:]' <${esc e.path})"
      launchctl setenv ${esc e.var} "$_val" 2>/dev/null || true
    fi
  '';

  linuxScript = lib.concatMapStrings emitLinux exports;
  darwinScript = lib.concatMapStrings emitDarwin exports;
  darwinSecretPathArgs = lib.concatMapStringsSep " " (e: esc e.path) exports;

  darwinSetenvScript = pkgs.writeShellScript "sops-launchctl-setenv" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}:/bin:/usr/bin:$PATH

    # LaunchAgents start concurrently at login; wait briefly for sops-nix to
    # materialize decrypted secrets before exporting launchd env.
    for _attempt in $(seq 1 60); do
      _ready=1
      for _path in ${darwinSecretPathArgs}; do
        if [ ! -r "$_path" ]; then
          _ready=0
          break
        fi
      done
      if [ "$_ready" = 1 ]; then
        break
      fi
      sleep 0.5
    done
    unset _attempt _path _ready

    ${darwinScript}
  '';

  shBlock = lib.concatMapStrings (e: ''
    if [ -r ${esc e.path} ]; then
      export ${e.var}=${esc (prefixOf e)}"$(tr -d '[:space:]' <${esc e.path})"
    fi
  '') exports;

  fishBlock = lib.concatMapStrings (e: ''
    if test -r ${esc e.path}
      set -gx ${e.var} ${esc (prefixOf e)}(cat ${esc e.path} | string trim)
    end
  '') exports;

  nuBlock = lib.concatMapStrings (
    e:
    let
      pJson = builtins.toJSON e.path;
      prefixJson = builtins.toJSON (prefixOf e);
    in
    ''
      if (${pJson} | path exists) {
        $env.${e.var} = ${prefixJson} + (${pJson} | open | str trim)
      }

    ''
  ) exports;
in
lib.mkMerge [
  (lib.mkIf (exports != [ ]) {
    programs.bash.initExtra = lib.mkAfter shBlock;
    programs.zsh.initContent = lib.mkAfter shBlock;
    programs.fish.interactiveShellInit = lib.mkAfter fishBlock;
    programs.nushell.extraEnv = lib.mkAfter nuBlock;
  })

  (lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && exports != [ ]) {
    home.activation.sopsSessionEnv = lib.hm.dag.entryAfter [ "sops-nix" ] ''
      export PATH=${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.systemd
        ]
      }:$PATH
      envDir=${esc envDir}
      envFile=${esc envFile}
      mkdir -p "$envDir"
      : >"$envFile"
      chmod 600 "$envFile"
      printf '# Auto-generated by sops-session-env.nix — do not edit.\n' >>"$envFile"

      ${linuxScript}
    '';
  })

  (lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && exports != [ ]) {
    launchd.agents.sops-session-env = {
      enable = true;
      config = {
        ProgramArguments = [ "${darwinSetenvScript}" ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };

    home.activation.sopsSessionEnv = lib.hm.dag.entryAfter [ "sops-nix" ] ''
      ${darwinSetenvScript} || true
    '';
  })
]
