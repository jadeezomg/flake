# Host status helpers emit one stdout line and exit 0 on probe failure so
# fastfetch or shell startup never fails because an optional service/API is down.
# Cache TTL is controlled by the Home Manager scheduler in
# modules/profiles/essentials/host-status.nix.
{ pkgs }:
let
  inherit (pkgs) lib;

  cacheDir = "$HOME/.cache/host-status";

  credentialCacheSources = {
    openrouter = {
      cachePath = "${cacheDir}/openrouter.json";
      intervalSec = 300; # 5 min — credit/usage moves slowly
      refresherName = "host-status-openrouter-refresh";
    };

    claude = {
      cachePath = "${cacheDir}/claude.json";
      intervalSec = 120; # 2 min — matches the dms-claudecode TTL
      refresherName = "host-status-claude-refresh";
    };
  };

  mkOpenRouterRefresh =
    source:
    pkgs.writeShellApplication {
      name = source.refresherName;
      runtimeInputs =
        with pkgs;
        [
          coreutils
          curl
          jq
        ]
        ++ lib.optional stdenv.hostPlatform.isLinux libsecret
        ++ lib.optional stdenv.hostPlatform.isDarwin _1password-cli;
      text = ''
        mkdir -p "${cacheDir}"
        cache="${source.cachePath}"
        tmp="$cache.tmp.$$"

        # Credential sources: 1Password on Darwin, libsecret on Linux.
        if [ "$(uname)" = "Darwin" ]; then
          key="$(op read "op://Personal/openrouter_api_key/credential" 2>/dev/null || true)"
        else
          key="$(secret-tool lookup service nono account openrouter_api_key 2>/dev/null || true)"
        fi

        if [ -z "$key" ]; then
          exit 0
        fi

        if curl -sSf -m 10 \
            -H "Authorization: Bearer $key" \
            "https://openrouter.ai/api/v1/key" >"$tmp" 2>/dev/null; then
          mv "$tmp" "$cache"
        else
          rm -f "$tmp"
        fi
      '';
    };

  mkClaudeRefresh =
    source:
    pkgs.writeShellApplication {
      name = source.refresherName;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        jq
      ];
      text = ''
        mkdir -p "${cacheDir}"
        cache="${source.cachePath}"
        tmp="$cache.tmp.$$"

        # Claude Code stores its OAuth blob in the macOS Keychain on Darwin
        # ("Claude Code-credentials"); Linux ships a plaintext credentials.json.
        if [ "$(uname)" = "Darwin" ]; then
          creds_json="$(/usr/bin/security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null || true)"
          [ -n "$creds_json" ] || exit 0
          token="$(printf '%s' "$creds_json" | jq -r '.claudeAiOauth.accessToken // ""' 2>/dev/null || true)"
        else
          creds="$HOME/.claude/.credentials.json"
          [ -r "$creds" ] || exit 0
          token="$(jq -r '.claudeAiOauth.accessToken // ""' "$creds" 2>/dev/null || true)"
        fi
        [ -n "$token" ] || exit 0

        version="$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9.]+' | head -1 || echo "2.0.0")"

        # Reverse-engineered from Claude Code OAuth traffic; not a public Anthropic API.
        if curl -sSf -m 10 \
            -H "Authorization: Bearer $token" \
            -H "Accept: application/json" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/$version" \
            "https://api.anthropic.com/api/oauth/usage" >"$tmp" 2>/dev/null; then
          if jq -e '.five_hour' >/dev/null 2>&1 <"$tmp"; then
            mv "$tmp" "$cache"
          else
            rm -f "$tmp"
          fi
        else
          rm -f "$tmp"
        fi
      '';
    };

  openrouterRefresh = mkOpenRouterRefresh credentialCacheSources.openrouter;
  claudeRefresh = mkClaudeRefresh credentialCacheSources.claude;

  hostStatus = pkgs.writeShellApplication {
    name = "host-status";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      git
      findutils
      gnugrep
      gawk
    ];
    text = ''
      cmd="''${1:-help}"
      shift || true

      tailscale_status() {
        if ! command -v tailscale >/dev/null 2>&1; then
          printf '(not installed)\n'; return 0
        fi
        local json backend peers
        json="$(tailscale status --json 2>/dev/null || echo '{}')"
        backend="$(printf '%s' "$json" | jq -r '.BackendState // "Unknown"')"
        if [ "$backend" != "Running" ]; then
          printf '%s\n' "''${backend,,}"
          return 0
        fi
        peers="$(printf '%s' "$json" | jq '(.Peer // {}) | length')"
        printf 'up - %s peers\n' "$peers"
      }

      containers_status() {
        if ! command -v podman >/dev/null 2>&1; then
          printf '(not installed)\n'; return 0
        fi
        # `podman ps` exits 125 when the socket is missing (Darwin: no
        # `podman machine`, Linux: socket not started). Detect that
        # explicitly so pipefail does not abort the whole script.
        local running_out total_out running total stopped
        if ! running_out="$(podman ps -q 2>/dev/null)"; then
          printf '(machine stopped)\n'; return 0
        fi
        total_out="$(podman ps -aq 2>/dev/null || true)"
        running="$(printf '%s' "$running_out" | grep -c . || true)"
        total="$(printf '%s' "$total_out" | grep -c . || true)"
        stopped=$(( total - running ))
        printf '%s running, %s stopped\n' "$running" "$stopped"
      }

      flake_status() {
        local dir="''${FLAKE:-$HOME/.dotfiles/flake}"
        if [ ! -d "$dir/.git" ]; then
          printf '(no flake)\n'; return 0
        fi
        local branch dirty
        branch="$(git -C "$dir" branch --show-current 2>/dev/null || echo '?')"
        dirty="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
        if [ "$dirty" -eq 0 ]; then
          printf '%s - clean\n' "$branch"
        else
          printf '%s - %s modified\n' "$branch" "$dirty"
        fi
      }

      generation_status() {
        local profile=/nix/var/nix/profiles/system
        if [ ! -e "$profile" ]; then
          printf '(no profile)\n'; return 0
        fi
        local gen_num mtime now age
        gen_num="$(readlink "$profile" | grep -oE '[0-9]+' | head -1)"
        # runtimeInputs puts GNU coreutils ahead of /usr/bin on PATH, so a
        # bare `stat -f %m` on Darwin would invoke GNU stat (which treats
        # `-f` as --file-system and emits a `File: ...` header). Pin to
        # BSD stat by absolute path; Linux keeps GNU semantics.
        if [ "$(uname)" = "Darwin" ]; then
          mtime="$(/usr/bin/stat -f %m "$profile" 2>/dev/null || echo 0)"
        else
          mtime="$(stat -c %Y "$profile" 2>/dev/null || echo 0)"
        fi
        now="$(date +%s)"
        age=$(( now - mtime ))
        if [ $age -lt 3600 ]; then
          printf '#%s - %sm ago\n' "$gen_num" "$(( age / 60 ))"
        elif [ $age -lt 86400 ]; then
          printf '#%s - %sh ago\n' "$gen_num" "$(( age / 3600 ))"
        else
          printf '#%s - %sd ago\n' "$gen_num" "$(( age / 86400 ))"
        fi
      }

      skills_status() {
        local dir="''${FLAKE:-$HOME/.dotfiles/flake}"
        local local_dir="$dir/data/agents/skills/local"
        local local_count=0
        if [ -d "$local_dir" ]; then
          local_count="$(find "$local_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
        fi
        printf 'apm: %s authored + upstream bundles\n' "$local_count"
      }

      openrouter_json() {
        local cache="${credentialCacheSources.openrouter.cachePath}"
        local display json limit usage remaining
        if [ ! -r "$cache" ]; then
          display='(no data — refresher not yet run)'
          jq -cn --arg display "$display" '{name:"openrouter", ok:false, state:"missing", display:$display}'
          return 0
        fi

        json="$(jq -c '.data as $d | if ($d | type) == "object" then {limit:($d.limit // null), usage:($d.usage // 0)} else empty end' "$cache" 2>/dev/null || true)"
        if [ -z "$json" ]; then
          display='(invalid cache)'
          jq -cn --arg display "$display" '{name:"openrouter", ok:false, state:"malformed", display:$display}'
          return 0
        fi

        limit="$(printf '%s' "$json" | jq -r '.limit // empty')"
        usage="$(printf '%s' "$json" | jq -r '.usage // 0')"
        if [ -n "$limit" ] && [ "$limit" != "null" ]; then
          remaining="$(awk -v l="$limit" -v u="$usage" 'BEGIN { printf "%.2f", l - u }')"
          display="$(printf '$%s left - $%.2f used' "$remaining" "$usage")"
        else
          display="$(printf '$%.2f used (no limit)' "$usage")"
        fi

        jq -cn --argjson data "$json" --arg display "$display" '{name:"openrouter", ok:true, state:"ready", display:$display} + $data'
      }

      claude_json() {
        local cache="${credentialCacheSources.claude.cachePath}"
        local display five seven json
        if [ ! -r "$cache" ]; then
          display='(no data — refresher not yet run)'
          jq -cn --arg display "$display" '{name:"claude", ok:false, state:"missing", display:$display}'
          return 0
        fi

        json="$(jq -c 'if (.five_hour | type) == "object" and (.seven_day | type) == "object" then {fiveHourUtilization:((.five_hour.utilization // 0) | floor), sevenDayUtilization:((.seven_day.utilization // 0) | floor)} else empty end' "$cache" 2>/dev/null || true)"
        if [ -z "$json" ]; then
          display='(invalid cache)'
          jq -cn --arg display "$display" '{name:"claude", ok:false, state:"malformed", display:$display}'
          return 0
        fi

        five="$(printf '%s' "$json" | jq -r '.fiveHourUtilization')"
        seven="$(printf '%s' "$json" | jq -r '.sevenDayUtilization')"
        display="$(printf '5h %s%% - 7d %s%%' "$five" "$seven")"
        jq -cn --argjson data "$json" --arg display "$display" '{name:"claude", ok:true, state:"ready", display:$display} + $data'
      }

      host_status_snapshot() {
        jq -cn \
          --argjson openrouter "$(openrouter_json)" \
          --argjson claude "$(claude_json)" \
          '{schemaVersion:1, caches:{openrouter:$openrouter, claude:$claude}}'
      }

      render_snapshot_value() {
        host_status_snapshot | jq -r --arg key "$1" '.caches[$key].display // "?"' 2>/dev/null || printf '?\n'
      }

      openrouter_status() {
        render_snapshot_value openrouter
      }

      claude_status() {
        render_snapshot_value claude
      }

      agents_status() {
        if command -v agent >/dev/null 2>&1; then
          agent status 2>/dev/null || printf '(unavailable)\n'
        else
          printf '(agent dispatcher not installed)\n'
        fi
      }

      all_status() {
        printf '%-12s %s\n' 'Generation'  "$(generation_status)"
        printf '%-12s %s\n' 'Flake'       "$(flake_status)"
        printf '%-12s %s\n' 'Tailscale'   "$(tailscale_status)"
        printf '%-12s %s\n' 'Containers'  "$(containers_status)"
        printf '%-12s %s\n' 'Agents'      "$(agents_status)"
        printf '%-12s %s\n' 'Claude'      "$(claude_status)"
        ${lib.optionalString (!pkgs.stdenv.hostPlatform.isDarwin) ''
          printf '%-12s %s\n' 'OpenRouter'  "$(openrouter_status)"
        ''}
        printf '%-12s %s\n' 'Skills'      "$(skills_status)"
      }

      case "$cmd" in
        tailscale)   tailscale_status ;;
        containers)  containers_status ;;
        flake)       flake_status ;;
        generation)  generation_status ;;
        skills)      skills_status ;;
        openrouter)  openrouter_status ;;
        claude)      claude_status ;;
        agents)      agents_status ;;
        snapshot|json) host_status_snapshot ;;
        render)      render_snapshot_value "''${1:-}" ;;
        all|"")      all_status ;;
        ls|list)
          printf '%s\n' tailscale containers flake generation skills openrouter claude agents
          ;;
        -h|--help|help)
          cat <<HELP
      usage: host-status <module>

      modules:
        tailscale    VPN backend state + peer count
        containers   podman running / stopped counts
        flake        \$FLAKE branch + dirty count
        generation   current NixOS generation # + age
        skills       upstream pin + local override count
        openrouter   cached OpenRouter credit/usage (refreshed by timer)
        claude       cached Claude Code 5h/7d rate-limit utilization (refreshed by timer)
        agents       proxy to \`agent status\` (running nono sessions)

      meta:
        all          print every module as a labelled list (default)
        snapshot     print structured Host Status JSON for Credential caches
        render       render one field from the structured Host Status JSON
        ls           list module names
        help         this message
      HELP
          ;;
        *)
          printf 'host-status: unknown module %q\n' "$cmd" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  inherit
    hostStatus
    credentialCacheSources
    openrouterRefresh
    claudeRefresh
    ;
}
