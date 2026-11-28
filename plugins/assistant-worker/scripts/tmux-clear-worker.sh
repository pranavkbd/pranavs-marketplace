#!/usr/bin/env bash
# Start a worker's next round: type /clear into its pane and wait until it has run. Same window,
# session name and permission mode. Send the next brief only after this succeeds.
# Usage: tmux-clear-worker.sh <worker name>
. "$(dirname "$0")/common.sh"
fail() { die "not cleared: $*"; }
target=$1
[ -n "$target" ] || die "usage: tmux-clear-worker.sh <worker name>"
require_tmux
pane=$(find_pane "$target") || exit 1
[ "$pane" != "$TMUX_PANE" ] || fail "that's this session's own pane"

# Only ever type into an idle worker with an empty input box
read_pane "$pane"
[ -n "$PID" ] || fail "Claude isn't running in that pane"
name=$(session_field "$PID" name)
old=$(session_field "$PID" sessionId)
[ -n "$old" ] || fail "Claude Code has no session record for it, so the clear couldn't be confirmed"
case $name in worker-*) ;; *) fail "'$name' isn't a worker" ;; esac
[ "$STATE" = idle ] || fail "$name is $STATE${WAITING:+ ($WAITING)}"
[ "$BOX" = yes ] || fail "its input box isn't on screen"
[ -z "$TYPED" ] || fail "there's unsent text in its input box: $TYPED"
[ "$(tmux display -p -t "$pane" '#{pane_in_mode}')" = 0 ] || fail "the pane is in copy mode (someone is scrolling it)"

tmux send-keys -t "$pane" -l /clear && sleep 0.5 && tmux send-keys -t "$pane" Enter || fail "tmux send-keys failed"

# /clear keeps the process and starts a new session ID. A message sent before that would be wiped.
for _ in $(seq 60); do
  sleep 0.5
  new=$(session_field "$PID" sessionId)
  if [ -n "$new" ] && [ "$new" != "$old" ]; then
    sleep 2
    echo "cleared $name: send it the next brief now"
    exit 0
  fi
done
die "typed /clear into $name but it hasn't run after 30s (it may be queued behind a turn); peek before sending anything"
