# agent-review: an omp agent in a new herdr pane reviews the change of the
# agent in the current pane. The two agents talk with `herdr agent prompt` in
# the herdr TUI, or with `hc send` in Herdr.app (herdr-core), so each message
# arrives as a user message in the other session. The skills request-review
# (author) and peer-review (reviewer) hold the protocol.
#
# State lives in <git dir>/agent-review/<review>/, outside the work tree:
# mux (herdr or hc), author (pane ID or hc terminal), reviewer (pane ID or hc
# terminal), base (commit), questions (count), findings.md (written by the
# reviewer).

max_questions=${AGENT_REVIEW_MAX_QUESTIONS:-5}
# The reviewer uses the model that omp has configured. AGENT_REVIEW_MODEL
# overrides it, for example on a host without the codex login:
# AGENT_REVIEW_MODEL=openrouter/deepseek/deepseek-v4-flash
model=${AGENT_REVIEW_MODEL:-}

usage() {
  cat <<'EOF'
usage:
  agent-review request [--base REF] [--note TEXT]
                                      author: start a review in a new pane
  agent-review show REVIEW            reviewer: base, author, changed files
  agent-review ask REVIEW QUESTION    reviewer: send a question to the author
  agent-review answer REVIEW ANSWER   author: send an answer to the reviewer
  agent-review done REVIEW            reviewer: send the findings to the author
EOF
}

die() {
  echo "agent-review: $*" >&2
  exit 1
}

state_root() {
  echo "$(git rev-parse --absolute-git-dir)/agent-review"
}

review_dir() {
  local review=$1 dir
  [[ $review =~ ^review-[0-9]+$ ]] || die "not a review name: $review"
  dir="$(state_root)/$review"
  [[ -f $dir/author ]] || die "no review $review in this repository"
  echo "$dir"
}

# The terminal multiplexer of a review: herdr (the TUI) or hc (Herdr.app).
# Reviews from before hc support have no mux file and ran in herdr.
review_mux() {
  if [[ -f $1/mux ]]; then cat "$1/mux"; else echo herdr; fi
}

# send MUX TARGET TEXT: submit TEXT as a prompt to the agent TARGET. If the
# agent waits for an approval, wait until it is free, then try again.
send() {
  local mux=$1 target=$2 text=$3 out rc
  for _ in 1 2 3; do
    if [[ $mux == hc ]]; then
      rc=0
      out=$(hc send "$target" "$text" 2>&1) || rc=$?
      ((rc != 0)) || return 0
      # Exit code 9: the agent waits for a person. Wait up to 5 minutes.
      if ((rc == 9)); then
        for _ in {1..30}; do
          [[ $(hc get "$target" --json | jq -r '.status.state // ""') == blocked ]] || break
          sleep 10
        done
        continue
      fi
    else
      if out=$(herdr agent prompt "$target" "$text" 2>&1); then
        return 0
      fi
      if [[ $out == *agent_blocked* ]]; then
        herdr agent wait "$target" --until idle --until "done" --timeout 300000 >/dev/null || true
        continue
      fi
    fi
    die "could not send to $target: $out"
  done
  die "$target is still blocked. Try again later."
}

# The merge base with the upstream branch: the review then covers unpushed
# commits and uncommitted changes.
default_base() {
  git merge-base HEAD '@{upstream}' 2>/dev/null ||
    git merge-base HEAD origin/HEAD 2>/dev/null ||
    git rev-parse HEAD
}

cmd_request() {
  local base="" note="" root review dir pane started="" task mux author labels
  local omp_args=("--skills=peer-review,ponytail-review,terminal-browser")
  [[ -z $model ]] || omp_args+=(--model="$model")
  while (($#)); do
    case $1 in
    --base)
      base=${2:?--base needs a ref}
      shift 2
      ;;
    --note)
      note=${2:?--note needs a text}
      shift 2
      ;;
    *) die "unknown option: $1" ;;
    esac
  done
  if [[ -n ${HERDR_PANE_ID:-} ]]; then
    mux=herdr author=$HERDR_PANE_ID
  elif [[ -n ${HC_TERMINAL_ID:-} ]]; then
    mux=hc author=$HC_TERMINAL_ID
  else
    die "run this inside a herdr pane or a Herdr.app terminal"
  fi
  root=$(git rev-parse --show-toplevel) || die "not in a git repository"
  base=$(git rev-parse --verify --quiet "${base:-$(default_base)}^{commit}") ||
    die "unknown base"
  if git diff --quiet "$base" && [[ -z $(git ls-files --others --exclude-standard) ]]; then
    die "nothing to review: no change since $base"
  fi

  review="review-$(date +%m%d%H%M%S)"
  dir="$(state_root)/$review"
  mkdir -p "$dir"
  echo "$mux" >"$dir/mux"
  echo "$author" >"$dir/author"
  echo "$base" >"$dir/base"
  echo 0 >"$dir/questions"
  [[ -z $note ]] || echo "$note" >"$dir/note"

  task="Use the peer-review skill to review $review. Start with: agent-review show $review"
  [[ -z $note ]] || task="$task -- Note from the author: $note"

  if [[ $mux == hc ]]; then
    # The author's herdr.space and herdr.tab labels put the reviewer into the
    # author's tab as a new pane. --no-parent: the reviewer stays when the
    # author session ends, as in herdr. The reviewer template (agent-review.nix)
    # holds the omp command; herdr-core sends the task once omp is ready.
    # AGENT_REVIEW_MODEL needs its own command line, so it skips the template.
    local start=(reviewer "$task") out
    [[ -z $model ]] || start=(omp "${omp_args[@]}" "$task")
    mapfile -t labels < <(hc get "$author" --json |
      jq -r '.labels // {} | to_entries[] | select(.key == "herdr.space" or .key == "herdr.tab") | "--label=\(.key)=\(.value)"')
    out=$(hc run --bg --no-parent --json --name "$review" --cwd "$root" "${labels[@]}" "${start[@]}")
    pane=$(jq -r '.address // empty' <<<"$out")
    [[ -n $pane ]] || die "could not start omp in Herdr.app: $out"
    echo "$pane" >"$dir/reviewer"
    if [[ $(jq -r '.first_message.sent' <<<"$out") == false ]]; then
      die "the task did not reach the reviewer ($(jq -r '.first_message.reason // "no reason"' <<<"$out")). Read it with: hc read $pane"
    fi
  else
    pane=$(herdr pane split --pane "$author" --direction right --cwd "$root" --no-focus |
      jq -r '.result.pane.pane_id')
    [[ -n $pane && $pane != null ]] || die "could not split the pane"
    echo "$pane" >"$dir/reviewer"

    # The new pane starts its shell first. `agent start` refuses a pane whose
    # shell is not ready yet, so try a few times. ponytail-review comes from the
    # ponytail Claude Code plugin (omp's claude-plugins source).
    for _ in 1 2 3 4 5; do
      if herdr agent start "$review" --kind omp --pane "$pane" --timeout 120000 \
        -- "${omp_args[@]}" >/dev/null 2>&1; then
        started=1
        break
      fi
      sleep 2
    done
    [[ -n $started ]] || die "could not start omp in pane $pane"
    send herdr "$review" "$task"
  fi
  echo "Review $review started in pane $pane with ${model:-the configured omp model}. End your turn now. The reviewer sends its questions and findings to this session as messages."
}

cmd_show() {
  local review=${1:?usage: agent-review show REVIEW} dir base note="(none)"
  dir=$(review_dir "$review")
  base=$(<"$dir/base")
  [[ ! -f $dir/note ]] || note=$(<"$dir/note")
  cat <<EOF
Review:    $review
Author:    pane $(<"$dir/author")
Base:      $base
Note:      $note
Findings:  $dir/findings.md
Questions: $(<"$dir/questions") of $max_questions asked

Commits since the base:
$(git log --oneline "$base..HEAD")

Tracked changes (git diff $base):
$(git diff --stat "$base")

Untracked files:
$(git ls-files --others --exclude-standard)
EOF
}

cmd_ask() {
  local review=${1:?usage: agent-review ask REVIEW QUESTION}
  local question=${2:?usage: agent-review ask REVIEW QUESTION}
  local dir asked
  dir=$(review_dir "$review")
  asked=$(<"$dir/questions")
  ((asked < max_questions)) ||
    die "you asked $max_questions questions, the limit. Write the open point into the findings."
  send "$(review_mux "$dir")" "$(<"$dir/author")" "[agent-review $review] Question from the reviewer: $question -- Answer with: agent-review answer $review \"<answer>\". If only the user knows the answer, ask the user first."
  echo $((asked + 1)) >"$dir/questions"
  echo "Sent. End your turn. The answer arrives as a new message."
}

cmd_answer() {
  local review=${1:?usage: agent-review answer REVIEW ANSWER}
  local answer=${2:?usage: agent-review answer REVIEW ANSWER}
  local dir
  dir=$(review_dir "$review")
  send "$(review_mux "$dir")" "$review" "[agent-review $review] Answer from the author: $answer"
  echo "Sent. End your turn."
}

cmd_done() {
  local review=${1:?usage: agent-review done REVIEW} dir
  dir=$(review_dir "$review")
  [[ -s $dir/findings.md ]] || die "write $dir/findings.md first"
  send "$(review_mux "$dir")" "$(<"$dir/author")" "[agent-review $review] Review finished. Findings: $dir/findings.md -- Read them, fix what you agree with, and tell the user what you fixed, what you did not fix, and why."
  echo "Sent. The review is complete."
}

case ${1:-} in
request | show | ask | answer | done)
  cmd=$1
  shift
  "cmd_$cmd" "$@"
  ;;
-h | --help)
  usage
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
