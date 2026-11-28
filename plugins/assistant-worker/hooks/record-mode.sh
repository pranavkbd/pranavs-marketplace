#!/usr/bin/env bash
# PreToolUse hook (Bash): note the assistant's current permission mode, so tmux-spawn.sh can give
# a new worker exactly that. Runs before every command, so it follows mode changes. Subagents are
# skipped: their mode can differ from the session's.
input=$(cat)
[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || exit 0
grep -q -E '"agent_type"[[:space:]]*:[[:space:]]*"([^"]*:)?assistant"' <<<"$input" || exit 0
grep -q -E '"agent_id"[[:space:]]*:' <<<"$input" && exit 0
. "$(dirname "$0")/../scripts/common.sh"
pid=$(own_claude_pid) || exit 0
mode=$(grep -o -E '"permission_mode"[[:space:]]*:[[:space:]]*"[A-Za-z]+"' <<<"$input" | head -1 | cut -d'"' -f4)
if [ -n "$mode" ]; then
  mkdir -p "$STATE_DIR" && printf '%s\n' "$mode" >"$STATE_DIR/mode-$pid"
else
  rm -f "$STATE_DIR/mode-$pid"
fi
exit 0
