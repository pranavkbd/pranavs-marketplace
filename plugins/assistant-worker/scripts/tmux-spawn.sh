#!/usr/bin/env bash
# Start a worker in a new tmux window, with the calling assistant's permission mode.
# Usage: tmux-spawn.sh <dir> [letter] [--model <model>]
# Prints the window name, which is also the worker's session name.
set -e
. "$(dirname "$0")/common.sh"
usage="usage: tmux-spawn.sh <dir> [letter] [--model <model>]"

dir= letter= model=
while [ $# -gt 0 ]; do
  case $1 in
    --model) [ -n "$2" ] || die "$usage"; model=$2; shift ;;
    --model=*) model=${1#*=} ;;
    -*) die "unknown option $1 ($usage)" ;;
    *) if [ -z "$dir" ]; then dir=$1
       elif [ -z "$letter" ] && [[ $1 == [A-Za-z] ]]; then letter=$(tr 'A-Z' 'a-z' <<<"$1")
       else die "unexpected argument $1 ($usage)"; fi ;;
  esac
  shift
done
[ -n "$dir" ] || die "$usage"
require_tmux
dir=$(cd "$dir" 2>/dev/null && pwd) || die "no such directory"

# Named exactly as shell/claude-pair.zsh names them: worker-<dir>, worker-<dir>-<letter>
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=$dir
base=$(basename "$top")
name="worker-${base// /-}"
if [ -n "$letter" ] && [ "$letter" != a ]; then name+="-$letter"; fi

# The permission mode comes only from what hooks/record-mode.sh saw for this command. Without it
# there is no way to be sure the worker isn't given more than the assistant has, so don't start.
me=$(own_claude_pid) || die "not started: run this from the assistant session"
mode=$(cat "$STATE_DIR/mode-$me" 2>/dev/null) ||
  die "not started: this session's permission mode is unknown. This works only from the assistant, with the plugin's hooks loaded"
case $mode in
  default) mode=manual ;;
  manual|acceptEdits|plan|auto|dontAsk|bypassPermissions) ;;
  *) die "not started: unrecognised permission mode '$mode'" ;;
esac

# Two sessions with one name can't be messaged apart
for file in "$CLAUDE_DIR"/sessions/*.json; do
  [ -f "$file" ] || continue
  pid=$(basename "$file" .json)
  if [ "$(session_field "$pid" name)" = "$name" ] && is_claude "$pid"; then
    die "not started: $name is already running (pid $pid)"
  fi
done
if tmux list-windows -a -F '#{window_name}' | grep -qxF -- "$name"; then
  die "not started: there's already a window called $name (peek at it; close it if it's finished)"
fi

cmd="claude --agent worker --name $(printf '%q' "$name") --permission-mode $mode"
[ -z "$model" ] || cmd+=" --model $(printf '%q' "$model")"

# A shell with the command typed into it, so an error stays on screen. -d leaves the user's focus.
session=$(tmux display -p -t "$TMUX_PANE" '#{session_id}')
read -r window pane <<<"$(tmux new-window -d -P -F '#{window_id} #{pane_id}' -t "$session:" -n "$name" -c "$dir")"
[ -n "$pane" ] || die "tmux couldn't open a window"
tmux set-option -w -t "$window" @assistant_worker 1
tmux set-option -w -t "$window" allow-rename off
tmux set-option -w -t "$window" automatic-rename off
tmux send-keys -t "$pane" -l "$cmd"
tmux send-keys -t "$pane" Enter

# Wait until it can take a message, so the caller can brief it straight away
for _ in $(seq 60); do
  sleep 0.5
  read_pane "$pane"
  case $STATE in
    idle|busy) echo "$name"; echo "started in window $window, $mode mode" >&2; exit 0 ;;
    waiting) echo "$name"
      echo "started in window $window, $mode mode, but it's waiting at a prompt only the user may answer; peek at it" >&2
      exit 0 ;;
  esac
done
die "opened window $window ($name) but Claude didn't come up within 30s; peek at it"
