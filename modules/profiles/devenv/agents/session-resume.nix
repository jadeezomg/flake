# Resume a Claude session of any host from the archive on mini
# (hosts/mini/services/agent-sessions.nix) on this host.
#
# `tv agent-sessions` lists the sessions from the agentsview API at
# sessions.jadee.fyi, shows the transcript as preview, and runs
# `agent-resume <id>` on Enter. The channel lives here and not in the
# television module, because it needs agent-resume and the archive is Linux only.
#
# agent-resume copies a session of another host from /srv/agent-sessions on
# mini with `ssh mini sudo cat`, because only root and agentsview can read the
# archive. Claude finds a session by the folder of its working directory, and
# every host keeps repos at ~/git/<repo> (D9 in
# docs/agents/session-management-plan.md), so the copy goes into the same
# project folder here. A session of another host resumes with --fork-session:
# the copy gets a new ID, so two hosts never push different files with one ID.
#
# Claude only: pi, omp, and codex keep sessions in other layouts.
{
  hostKey,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  api = "https://sessions.jadee.fyi/api/v1/sessions";

  list = pkgs.writeShellApplication {
    name = "agent-sessions-list";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      curl -fsS "${api}?agent=claude&limit=1000" |
        jq -r '.sessions[] | [.id, .machine, (.ended_at // .started_at // "")[0:16], .cwd,
          ((.display_name // .first_message // "") | gsub("\\s+"; " ") | .[0:80])] | @tsv'
    '';
  };

  resume = pkgs.writeShellApplication {
    name = "agent-resume";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      openssh
    ];
    text = ''
      id=''${1:?usage: agent-resume <session-id>}
      # id and the host name go into a command on mini.
      if [[ ! $id =~ ^[A-Za-z0-9-]+$ ]]; then
        echo "agent-resume: unexpected session id '$id'" >&2
        exit 1
      fi
      info=$(curl -fsS "${api}/$id" | jq -r '[.agent, .machine, .cwd] | @tsv')
      IFS=$'\t' read -r agent machine cwd <<<"$info"
      if [[ $agent != claude || ! $machine =~ ^[a-z0-9-]+$ ]]; then
        echo "agent-resume: $id is a '$agent' session of host '$machine'. Only Claude sessions resume here." >&2
        exit 1
      fi
      if [[ ! -d $cwd ]]; then
        echo "agent-resume: $cwd does not exist on this host. Clone or pull the repo first." >&2
        exit 1
      fi

      # Claude's project folder name: the path with every other character as "-".
      slug=''${cwd//[^a-zA-Z0-9]/-}
      dest="$HOME/.claude/projects/$slug/$id.jsonl"
      fork=()
      if [[ $machine != ${hostKey} ]]; then
        fork=(--fork-session)
      fi
      if [[ $machine != ${hostKey} || ! -f $dest ]]; then
        mkdir -p "$(dirname "$dest")"
        # MINI_SSH: same override as the mini just recipes.
        ssh -o ConnectTimeout=10 "''${MINI_SSH:-mini}" \
          sudo cat "/srv/agent-sessions/$machine/claude/$slug/$id.jsonl" >"$dest.part"
        mv -f "$dest.part" "$dest"
      fi

      cd "$cwd"
      exec claude --resume "$id" "''${fork[@]}"
    '';
  };

  channel = (pkgs.formats.toml { }).generate "agent-sessions.toml" {
    metadata = {
      name = "agent-sessions";
      description = "Claude sessions of every host, from the archive on mini";
    };
    # Columns: id, host, last activity, working directory, title.
    source = {
      command = lib.getExe list;
      display = "{split:\\t:1}  {split:\\t:2}  {split:\\t:3}  {split:\\t:4}";
      # The API sorts by last activity.
      no_sort = true;
      frecency = false;
      shell = "bash";
    };
    preview = {
      command = "${lib.getExe pkgs.curl} -fsS '${api}/{split:\\t:0}/md'";
      shell = "bash";
    };
    keybindings.enter = "actions:resume";
    actions.resume = {
      description = "Resume the session on this host";
      command = "${lib.getExe resume} '{split:\\t:0}'";
      mode = "execute";
      shell = "bash";
    };
  };
in
lib.mkIf (!isDarwin) {
  home.packages = [ resume ];
  xdg.configFile."television/cable/agent-sessions.toml".source = channel;
}
