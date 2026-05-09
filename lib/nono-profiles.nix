# Single source of truth for nono-sandboxed agent profiles and wrappers.
# omp (oh-my-pi) is a fork of pi-mono with extended tooling. It coexists with
# pi side-by-side: same OpenRouter broker route, same git identity, isolated
# config directories (~/.omp vs ~/.pi). omp ships native --mode acp so its Zed
# integration goes direct (no pi-acp adapter).
#
# Architecture decisions: docs/adr/0001-nono-as-single-sandboxing-system.md.
#
{pkgs}: let
  inherit (pkgs) lib;

  # Per-platform credential-key resolution.
  #   Linux  → libsecret account name (service "nono", account <name>)
  #   Darwin → 1Password URI under the Personal vault
  # The vault name is duplicated in home/shared/shells/sops-1password.nix.
  # Item-naming convention is shared so the same `<name>` works on both.
  opVault = "Personal";
  mkCredentialKey = name:
    if pkgs.stdenv.isDarwin
    then "op://${opVault}/${name}/credential"
    else name;

  loopbackPorts = [
    3000
    3001
    3306
    3333
    4000
    4173
    5000
    5173
    5432
    5555
    6379
    7000
    8000
    8080
    8081
    8443
    8888
    9000
    9001
    9090
    9200
    9229
    11434
  ];

  # The rootless podman socket lets agents reach host-managed containers.
  # Sockets must go in `allow_file` (r+w on a single path); `unix_socket`
  # grants read-only and isn't enough for podman's bidirectional protocol.
  sharedUnixSockets = [
    "$XDG_RUNTIME_DIR/podman/podman.sock"
  ];

  # Broker credential routes read keystore accounts populated by
  # home/shared/shells/sops-keyring.nix at HM activation.
  sharedCustomCredentials = {
    context7 = {
      upstream = "https://context7.com";
      credential_key = mkCredentialKey "context7_api_key";
      inject_mode = "header";
      inject_header = "Authorization";
      credential_format = "Bearer {}";
    };
    # Overrides nono's built-in `github` (which reads env://GITHUB_TOKEN);
    # ours pulls from the platform keystore instead so the value never
    # enters host env.
    github = {
      upstream = "https://api.github.com";
      credential_key = mkCredentialKey "github_token";
      inject_mode = "header";
      inject_header = "Authorization";
      credential_format = "token {}";
    };
  };

  mkAgentProfile = {
    name,
    description,
    baseProfiles,
    dotDirs ? [],
    extraCredentials ? {},
    extraServiceList ? [],
  }: {
    meta = {
      inherit name description;
      version = "1.0.0";
    };
    extends = baseProfiles;
    network = {
      # `developer` engages the broker with these domain groups: llm_apis,
      # package_registries, github, sigstore, documentation. Without it,
      # populating `credentials` triggers proxy filtering with an empty
      # allowlist and everything (incl. localhost) is blocked.
      network_profile = "developer";
      # Hosts our custom_credentials inject auth for. Listed so `nono why`
      # static analysis matches runtime — without this, `nono why` reports
      # DENIED for these even though the broker rewrites them at runtime.
      allow_domain =
        ["context7.com"]
        ++ lib.optional (extraCredentials ? openrouter) "openrouter.ai";
      open_port = loopbackPorts;
      custom_credentials = sharedCustomCredentials // extraCredentials;
      credentials = ["context7" "github"] ++ extraServiceList;
    };
    filesystem = {
      allow = dotDirs;
      allow_file = sharedUnixSockets;
    };
    workdir.access = "readwrite";
  };

  profiles = {
    claude-flake = mkAgentProfile {
      name = "claude-flake";
      description = "Claude Code — broker creds, podman socket, loopback dev ports";
      baseProfiles = ["claude-code"];
      # ~/.claude / ~/.claude.json already granted by the claude-code base.
    };

    pi-flake = mkAgentProfile {
      name = "pi-flake";
      description = "pi coding agent — OpenRouter broker, podman socket, loopback dev ports";
      baseProfiles = ["linux-host-compat"];
      dotDirs = [
        "$HOME/.pi"
        "$HOME/.npm-global"
        "$HOME/.npm"
      ];
      extraCredentials = {
        openrouter = {
          upstream = "https://openrouter.ai/api/v1";
          credential_key = mkCredentialKey "openrouter_api_key";
          inject_mode = "header";
          inject_header = "Authorization";
          credential_format = "Bearer {}";
        };
      };
      extraServiceList = ["openrouter"];
    };

    omp-flake = mkAgentProfile {
      name = "omp-flake";
      description = "oh-my-pi (omp) — OpenRouter broker, podman socket, loopback dev ports";
      baseProfiles = ["linux-host-compat"];
      # omp's plugin manager shells out to `bun install` against
      # ~/.omp/plugins/, so the npm dotdirs are kept in scope alongside ~/.omp.
      dotDirs = [
        "$HOME/.omp"
        "$HOME/.npm-global"
        "$HOME/.npm"
      ];
      extraCredentials = {
        openrouter = {
          upstream = "https://openrouter.ai/api/v1";
          credential_key = mkCredentialKey "openrouter_api_key";
          inject_mode = "header";
          inject_header = "Authorization";
          credential_format = "Bearer {}";
        };
      };
      extraServiceList = ["openrouter"];
    };
  };

  metadata = {
    claude = {
      profileName = "claude-flake";
      pkg = pkgs.claude-code;
      bin = "claude";
      gitName = "claude-jadee";
      gitEmail = "claude@jadee.fyi";
      # nono is now the security boundary; Claude's internal permission
      # prompts become friction. Per nono docs/cli/clients/claude-code.
      extraArgs = ["--dangerously-skip-permissions"];
    };
    pi = {
      profileName = "pi-flake";
      pkg = pkgs.pi-coding-agent;
      bin = "pi";
      gitName = "pi-jadee";
      gitEmail = "pi@jadee.fyi";
      extraArgs = [];
    };
    # omp shares pi's identity since both are pi-derived; commits should
    # attribute to "the pi family". Differentiation is by config dir
    # (~/.omp vs ~/.pi), not by author.
    omp = {
      profileName = "omp-flake";
      pkg = pkgs.oh-my-pi;
      bin = "omp";
      gitName = "pi-jadee";
      gitEmail = "pi@jadee.fyi";
      extraArgs = [];
    };
  };

  agentPackageAttrs = lib.mapAttrs (_: meta: meta.pkg) metadata;
  agentPackages = lib.attrValues agentPackageAttrs;
  mkAgentEnvArgs = meta: [
    "GIT_AUTHOR_NAME=${lib.escapeShellArg meta.gitName}"
    "GIT_AUTHOR_EMAIL=${lib.escapeShellArg meta.gitEmail}"
    "GIT_COMMITTER_NAME=${lib.escapeShellArg meta.gitName}"
    "GIT_COMMITTER_EMAIL=${lib.escapeShellArg meta.gitEmail}"
    "GIT_CONFIG_GLOBAL=${agentGitconfig}"
  ];

  mkAgentProfileFile = agentName: let
    meta = metadata.${agentName};
  in
    pkgs.writeText "${meta.profileName}.json"
    (builtins.toJSON profiles.${meta.profileName});

  mkAgentInvocation = {
    agentName,
    detached ? false,
    passArgs ? false,
    usePackagePath ? true,
  }: let
    meta = metadata.${agentName};
    profileFile = mkAgentProfileFile agentName;
    nonoArgs =
      ["run"]
      ++ lib.optional detached "--detached"
      ++ [
        "--profile"
        "${profileFile}"
        "--allow-cwd"
        "--rollback"
        "--"
        "${pkgs.coreutils}/bin/env"
      ]
      ++ mkAgentEnvArgs meta;
    executable =
      if usePackagePath
      then "${meta.pkg}/bin/${meta.bin}"
      else meta.bin;
    agentArgs = [executable] ++ meta.extraArgs;
    argv = map toString nonoArgs ++ map lib.escapeShellArg agentArgs ++ lib.optional passArgs ''"$@"'';
  in
    lib.concatStringsSep " " argv;

  prepareCommitMsg = pkgs.writeShellScript "agent-prepare-commit-msg" ''
    set -e
    [ -n "$1" ] && [ -f "$1" ] || exit 0
    ${pkgs.git}/bin/git interpret-trailers \
      --if-exists doNothing \
      --trailer "Co-Authored-By: jadeezomg <github@jadee.fyi>" \
      --in-place "$1"
  '';

  hooksDir = pkgs.runCommand "agent-git-hooks" {} ''
    mkdir -p $out
    cp ${prepareCommitMsg} $out/prepare-commit-msg
    chmod +x $out/prepare-commit-msg
  '';

  agentGitconfig = pkgs.writeText "agent-gitconfig" ''
    [core]
    	hooksPath = ${hooksDir}
  '';

  mkAgentBin = agentName:
    pkgs.writeShellApplication {
      name = "agent-${agentName}";
      runtimeInputs = [pkgs.nono];
      text = ''
        exec ${mkAgentInvocation {
          inherit agentName;
          passArgs = true;
        }}
      '';
    };

  agentNames = lib.attrNames metadata;
  agentBins = lib.genAttrs agentNames mkAgentBin;

  credentialAccounts = ["openrouter_api_key" "context7_api_key" "github_token"];
  profileNames = map (n: metadata.${n}.profileName) agentNames;

  linuxChecks =
    [
      {
        label = "gnome-keyring-daemon serving org.freedesktop.secrets";
        cmd = "${pkgs.dbus}/bin/dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner string:org.freedesktop.secrets >/dev/null 2>&1";
      }
    ]
    ++ map (acc: {
      label = "keyring: ${acc} present";
      cmd = "${pkgs.libsecret}/bin/secret-tool lookup service nono account ${acc} >/dev/null 2>&1";
    })
    credentialAccounts;

  darwinChecks =
    [
      {
        label = "1Password CLI signed in";
        cmd = "${pkgs._1password-cli}/bin/op whoami >/dev/null 2>&1";
      }
    ]
    ++ map (acc: {
      label = "1password: ${opVault}/${acc} present";
      cmd = "${pkgs._1password-cli}/bin/op item get ${acc} --vault ${opVault} >/dev/null 2>&1";
    })
    credentialAccounts;

  commonChecks =
    [
      {
        label = "podman rootless socket reachable";
        cmd = ''[ -S "''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/podman/podman.sock" ]'';
      }
    ]
    ++ map (p: {
      label = "nono profile resolves: ${p}";
      cmd = "${pkgs.nono}/bin/nono profile show ${p} >/dev/null 2>&1";
    })
    profileNames;

  platformChecks =
    if pkgs.stdenv.isDarwin
    then darwinChecks
    else linuxChecks;
  doctorChecks = platformChecks ++ commonChecks;

  # Each check becomes a bash function so shellcheck sees a real shell AST
  # rather than a quoted command-as-string passed to `eval`.
  indexedChecks = lib.imap0 (i: c: c // {fn = "chk_${toString i}";}) doctorChecks;

  doctor = pkgs.writeShellApplication {
    name = "agent-doctor";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      fail=0
      run() {
        local label="$1"
        local fn="$2"
        if "$fn" >/dev/null 2>&1; then
          printf '  \033[32m+\033[0m %s\n' "$label"
        else
          printf '  \033[31m-\033[0m %s\n' "$label"
          fail=$((fail + 1))
        fi
      }

      ${lib.concatMapStringsSep "\n" (c: ''
          ${c.fn}() {
            ${c.cmd}
          }
        '')
        indexedChecks}

      printf '\nagent doctor - verifying nono sandbox setup\n\n'
      ${lib.concatMapStringsSep "\n" (c: ''
          run ${lib.escapeShellArg c.label} ${c.fn}
        '')
        indexedChecks}

      if [ $fail -gt 0 ]; then
        printf '\n\033[31m%d check(s) failed\033[0m\n\n' "$fail"
        printf 'Hints:\n'
        printf '  - credential entries missing -> run home-manager switch (sops-keyring / sops-1password activation)\n'
        printf '  - podman socket missing -> systemctl --user enable --now podman.socket (Linux) or podman machine start (Darwin)\n'
        printf '  - profile not resolving -> check ~/.config/nono/profiles/ after HM switch\n'
        printf '  - 1Password not signed in -> op signin then re-run home-manager switch\n'
        exit 1
      fi
      printf '\nall checks passed.\n'
    '';
  };

  status = pkgs.writeShellApplication {
    name = "agent-status";
    runtimeInputs = [pkgs.nono pkgs.jq];
    text = ''
      json="$(nono --silent ps --json 2>/dev/null || echo '[]')"
      count="$(printf '%s' "$json" | jq 'length' 2>/dev/null || echo 0)"
      if [ "$count" = "0" ]; then
        printf 'none\n'
        exit 0
      fi
      summary="$(printf '%s' "$json" | jq -r 'map("\(.name) [\(.status)/\(.attachment)]") | join(", ")')"
      printf '%s session(s): %s\n' "$count" "$summary"
    '';
  };

  agent = pkgs.writeShellApplication {
    name = "agent";
    runtimeInputs = lib.attrValues agentBins ++ [doctor status pkgs.nono];
    text = ''
      usage() {
        cat <<HELP
      usage: agent <command> [args...]

      run an agent in its sandbox:
        ${lib.concatMapStringsSep "\n  " (n: "${n} [args...]    invoke ${metadata.${n}.bin} via ${metadata.${n}.profileName}") agentNames}

      session management (forwarded to nono):
        ps                list running / detached sandbox sessions
        attach <session>  attach to a detached session (Ctrl-] d to detach)
        stop <session>    stop a running session

      diagnostics:
        doctor            verify keyring, podman, profiles
        status            one-line summary of running sessions (banner-friendly)
        ls                list available agents
        help, -h, --help  show this message
      HELP
      }

      if [ $# -lt 1 ]; then
        usage >&2
        exit 2
      fi
      cmd="$1"
      shift
      case "$cmd" in
      ${lib.concatMapStringsSep "\n" (n: "  ${n}) exec agent-${n} \"$@\" ;;") agentNames}
        ps)        exec nono ps "$@" ;;
        attach)    exec nono attach "$@" ;;
        stop)      exec nono stop "$@" ;;
        doctor)    exec agent-doctor "$@" ;;
        status)    exec agent-status "$@" ;;
        ls|list)   printf '%s\n' ${lib.concatStringsSep " " agentNames} ;;
        -h|--help|help) usage ;;
        *)
          printf 'agent: unknown command %q\n' "$cmd" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  inherit profiles metadata mkAgentProfileFile mkAgentInvocation mkAgentBin agentPackageAttrs agentPackages agentBins agent doctor status agentGitconfig;
}
