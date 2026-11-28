#!/usr/bin/env bash
# SessionStart hook: inside tmux, load TMUX.md (how to self-clear) into context.
cat >/dev/null
[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || exit 0
root=$(cd "$(dirname "$0")/.." && pwd)
text=$(cat "$root/TMUX.md") || exit 0
printf '%s\n' "${text//'${CLAUDE_PLUGIN_ROOT}'/"$root"}"
