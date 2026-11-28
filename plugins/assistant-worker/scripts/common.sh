# Shared helpers for the tmux scripts and hooks. Sourced, not run.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STATE_DIR="$CLAUDE_DIR/assistant-worker"

die() { echo "assistant-worker: $*" >&2; exit 1; }

require_tmux() {
  [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || die "not running in tmux"
  [ "$(tmux display -p -t "$TMUX_PANE" '#{pane_id}' 2>/dev/null)" = "$TMUX_PANE" ] ||
    die "tmux pane $TMUX_PANE not found"
}

# is_claude PID: whether that process is Claude Code
is_claude() {
  local comm
  comm=$(ps -o comm= -p "$1" 2>/dev/null) || return 1
  case "${comm##*/}" in
    claude|claude.exe) return 0 ;;
    node) case "$(ps -o args= -p "$1" 2>/dev/null)" in *claude-code*|*/claude\ *|*/claude) return 0 ;; esac ;;
  esac
  return 1
}

# The Claude Code process this script or hook runs under. It survives /clear.
own_claude_pid() {
  local p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    is_claude "$p" && { echo "$p"; return 0; }
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  return 1
}

# pane_claude_pid PANE: the Claude Code process in the pane's foreground, if there is one
pane_claude_pid() {
  local tty pid stat
  tty=$(tmux display -p -t "$1" '#{pane_tty}' 2>/dev/null) || return 1
  while read -r pid stat; do
    case $stat in *+*) is_claude "$pid" && { echo "$pid"; return 0; } ;; esac
  done <<<"$(ps -t "${tty#/dev/}" -o pid=,stat= 2>/dev/null)"
  return 1
}

# session_field PID KEY: a string field from Claude Code's record of a running session
# (~/.claude/sessions/<pid>.json: name, sessionId, status, waitingFor, tmux). The format isn't
# documented, so callers must cope with getting nothing.
session_field() {
  grep -o "\"$2\":\"[^\"]*\"" "$CLAUDE_DIR/sessions/$1.json" 2>/dev/null | head -1 | cut -d'"' -f4
}

# find_pane TARGET: the pane for a worker's session name, window name, window ID (@3) or pane
# ID (%7). A window with several panes resolves to the one running Claude.
find_pane() {
  local target=$1 file pid pane found
  case $target in
    %*) [ "$(tmux display -p -t "$target" '#{pane_id}' 2>/dev/null)" = "$target" ] && { echo "$target"; return; }
        die "no tmux pane $target" ;;
  esac
  # by session name, wherever its pane is
  for file in "$CLAUDE_DIR"/sessions/*.json; do
    [ -f "$file" ] || continue
    pid=$(basename "$file" .json)
    [ "$(session_field "$pid" name)" = "$target" ] || continue
    pane=$(session_field "$pid" tmux); pane=${pane##*.}
    case $pane in %*) [ "$(pane_claude_pid "$pane")" = "$pid" ] && { echo "$pane"; return; } ;; esac
  done
  # by window: names are compared as text, since tmux reads a "." in a target as a pane
  found=$(tmux list-panes -a -F '#{pane_id} #{window_id} #{window_name}' |
    while read -r pane window name; do
      [ "$window" = "$target" ] || [ "$name" = "$target" ] || continue
      if pane_claude_pid "$pane" >/dev/null; then echo "1 $window $pane"; else echo "2 $window $pane"; fi
    done | sort -s -k1,1n)
  [ -n "$found" ] || die "no tmux window or worker called $target"
  [ "$(cut -d' ' -f2 <<<"$found" | sort -u | wc -l)" -eq 1 ] ||
    die "several windows are called $target; use a window ID: $(cut -d' ' -f2 <<<"$found" | sort -u | tr '\n' ' ')"
  head -1 <<<"$found" | cut -d' ' -f3
}

# read_pane PANE: sets, from what's on screen and Claude Code's session record,
#   PID     the Claude process ("" if it isn't running)
#   STATE   busy | idle | waiting | not running | unknown
#   WAITING what it's waiting for, when Claude Code says
#   BODY    the screen above the input box (all of it when a dialog replaced the box)
#   FOOTER  the status lines below the input box
#   BOX     yes when the input box is on screen
#   TYPED   unsent text in the input box
read_pane() {
  local pane=$1 screen styled parts status
  screen=$(tmux capture-pane -p -t "$pane") || die "can't read pane $pane"
  styled=$(tmux capture-pane -p -e -t "$pane")
  PID=$(pane_claude_pid "$pane") || PID=

  # The input box is the last "❯" line directly under a horizontal rule, closed by another rule.
  parts=$(awk '
    { line[NR] = $0 }
    END {
      for (i = NR; i > 1; i--) if (line[i] ~ /^❯/ && line[i-1] ~ /^───/) {
        for (j = i + 1; j <= NR; j++) if (line[j] ~ /^───/) { print i - 1, j; exit }
      }
    }' <<<"$screen")
  BOX=no; BODY=$screen; FOOTER=; TYPED=
  if [ -n "$parts" ]; then
    local top=${parts% *} bottom=${parts#* }
    BOX=yes
    BODY=$(head -n $((top - 1)) <<<"$screen")
    FOOTER=$(tail -n +$((bottom + 1)) <<<"$screen")
    # Placeholders and suggestions are dim and the IDE's selection chip is bracketed: neither
    # was typed.
    TYPED=$(sed -n "$((top + 1)),$((bottom - 1))p" <<<"$styled" |
      sed -E $'s/\e\\[7m.\e\\[0m//g; s/\e\\[2m([^\e]|\e\\[[0-9;]*[1-9][0-9;]*m)*(\e\\[0m|\e\\[22m|$)//g; s/\e\\[[0-9;]*m//g' |
      sed -E 's/^❯//; s/\[⧉[^]]*\]//; s/\xc2\xa0/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//' | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')
  fi

  WAITING=
  if [ -z "$PID" ]; then STATE='not running'; return; fi
  status=$(session_field "$PID" status)
  case $status in
    busy|idle) STATE=$status ;;
    waiting) STATE=waiting; WAITING=$(session_field "$PID" waitingFor) ;;
    *) # no record (a startup dialog, or a version that writes none): go by the screen
      if grep -q 'esc to interrupt' <<<"$FOOTER"; then STATE=busy
      elif [ $BOX = yes ]; then STATE=idle
      elif grep -q -E 'Esc to (cancel|exit)|Enter to (confirm|select)|Do you (want|trust)' <<<"$screen"; then STATE=waiting
      else STATE=unknown; fi ;;
  esac
}
