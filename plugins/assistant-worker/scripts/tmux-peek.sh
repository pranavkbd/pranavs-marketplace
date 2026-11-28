#!/usr/bin/env bash
# A few-line summary of a worker's tmux pane: state, context %, permission mode, any pending
# prompt or unsent input, and the last lines of output.
# Usage: tmux-peek.sh <worker name | window name | @window | %pane> [lines of output, default 4]
. "$(dirname "$0")/common.sh"
target=$1 count=${2:-4}
[ -n "$target" ] || die "usage: tmux-peek.sh <worker name> [lines]"
[ -n "$TMUX" ] || die "not running in tmux"
pane=$(find_pane "$target") || exit 1
read_pane "$pane"

# "ctx ── 6%" from a status line, else Claude Code's own low-context notice
ctx=$(grep -o 'ctx [^|]*' <<<"$FOOTER" | grep -o '[0-9]*%' | head -1)
[ -n "$ctx" ] || ctx=$(grep -o -i -E 'context (left|low)[^0-9]*[0-9]+%[^·|]*' <<<"$BODY"$'\n'"$FOOTER" | tail -1)
mode=$(grep -o -E '(manual|auto|plan) mode on|accept edits on|bypass permissions on|don.t ask( mode)? on' <<<"$FOOTER" | head -1)
read -r window spawned <<<"$(tmux display -p -t "$pane" '#{window_id} #{@assistant_worker}')"

head="$target: $STATE${WAITING:+ ($WAITING)}, ctx ${ctx:-?}${mode:+, $mode}, window $window"
[ -n "$spawned" ] && head+=" (spawned by tmux-spawn.sh)"
echo "$head"
[ -n "$TYPED" ] && echo "  UNSENT INPUT: ${TYPED:0:200}"

# drop blank lines, rules, tips and usage notices
clean() { grep -v -E '^[[:space:]⠀]*$|^[[:space:]]*[─━╌]{3}|^[[:space:]]*Tip:|You.ve used [0-9]+% of' | cut -c1-200; }
if [ "$STATE" = waiting ]; then
  # the dialog is the bottom of the screen: show enough of it to say what's being asked
  echo "  PROMPT:"
  clean <<<"$BODY" | tail -n 12 | sed 's/^/  | /'
else
  clean <<<"$BODY" | tail -n "$count" | sed 's/^/  /'
fi
