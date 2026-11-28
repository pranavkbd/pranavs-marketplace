#!/usr/bin/env bash
# SessionStart hook: inside tmux, load TMUX-assistant.md or TMUX-worker.md into context, by the
# session's agent. Does nothing for other sessions or outside tmux.
input=$(cat)
[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || exit 0
role=$(grep -o -E '"agent_type"[[:space:]]*:[[:space:]]*"([^"]*:)?(assistant|worker)"' <<<"$input" |
  head -1 | grep -o -E '(assistant|worker)"$' | tr -d '"')
[ -n "$role" ] || exit 0
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/scripts/common.sh"
if [ "$role" = assistant ]; then
  # forget permission modes left by sessions long gone
  find "$STATE_DIR" -name 'mode-*' -mtime +7 -delete 2>/dev/null
fi
text=$(cat "$root/TMUX-$role.md") || exit 0
printf '%s\n' "${text//'${CLAUDE_PLUGIN_ROOT}'/"$root"}"
