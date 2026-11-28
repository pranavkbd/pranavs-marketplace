#!/usr/bin/env bash
# Clear this session from inside tmux: type /clear into Claude Code's own pane, then "go" once the
# fresh session has picked up the handoff. Run after mark-handoff.sh, as the turn's last command.
# Usage: tmux-clear.sh
set -e
. "$(dirname "$0")/common.sh"
fail() { echo "clear-me-now: not clearing: $*" >&2; exit 1; }

[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || fail "not running in tmux"
info=$(tmux display -p -t "$TMUX_PANE" '#{pane_id} #{pane_tty}' 2>/dev/null) || info=
[ "${info%% *}" = "$TMUX_PANE" ] || fail "tmux pane $TMUX_PANE not found"

pending=$(pending_file)
[ -f "$pending" ] || fail "no handoff marked, run mark-handoff.sh first"

# TMUX_PANE is inherited by anything started from the pane (a nested or background Claude), so
# check that this Claude process is the one in the pane's foreground before typing into it.
key=$(session_key)
case $key in pid-*) pid=${key#pid-} ;; *) fail "can't find the Claude Code process" ;; esac
read -r tty stat <<<"$(ps -o tty=,stat= -p "$pid")"
[ "/dev/$tty" = "${info#* }" ] && [[ $stat == *+* ]] || fail "this session isn't the one shown in pane $TMUX_PANE"

# Detached, so it outlives this command. Claude Code queues a /clear typed mid-turn and runs it
# when the turn ends. on-clear.sh deletes the pending file, which is the cue to send "go"; if
# that never happens (turn interrupted, say), nothing more is typed.
setsid bash -c '
  pane=$1 pending=$2
  type_line() {
    # in copy mode the keys would drive tmux, not Claude: wait for the user to leave it
    for _ in $(seq 600); do
      [ "$(tmux display -p -t "$pane" "#{pane_in_mode}")" = 0 ] && break
      sleep 1
    done
    [ "$(tmux display -p -t "$pane" "#{pane_in_mode}")" = 0 ] || return 1
    tmux send-keys -t "$pane" -l "$1" && sleep 0.5 && tmux send-keys -t "$pane" Enter
  }
  sleep 1
  type_line /clear || exit 0
  for _ in $(seq 240); do
    if [ ! -f "$pending" ]; then sleep 2; type_line go; exit 0; fi
    sleep 0.5
  done
' tmux-clear "$TMUX_PANE" "$pending" </dev/null >/dev/null 2>&1 &

echo "clear-me-now: /clear is on its way to pane $TMUX_PANE; it runs when this turn ends."
