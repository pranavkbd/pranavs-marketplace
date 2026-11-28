#!/usr/bin/env bash
# quietlint PostToolUse hook (Edit|Write|MultiEdit|NotebookEdit).
#
# Records the edited file in this session's list, so check-turn.sh can check exactly the files
# this session touched when the turn ends. Runs nothing and prints nothing.
#
# The list lives in the repo's git dir: <git-dir>/quietlint/<session_id>, one path per line,
# relative to the repo root. Only repos with .claude/quietlint.json (written by
# /quietlint:setup) are recorded.

input=$(cat)
path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null)
session=$(jq -r '.session_id // "unknown"' <<<"$input" 2>/dev/null | tr -c 'A-Za-z0-9_.\n-' '_')
[ -n "$session" ] || session=unknown
[ -n "$path" ] || exit 0
dir=$(dirname "$path")
[ -d "$dir" ] || exit 0
dir=$(cd "$dir" && pwd -P)

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/.claude/quietlint.json" ] || exit 0
gitdir=$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null) || exit 0

file="$dir/$(basename "$path")"
rel=${file#"$root"/}
[ "$rel" != "$file" ] || exit 0

mkdir -p "$gitdir/quietlint" 2>/dev/null && printf '%s\n' "$rel" >>"$gitdir/quietlint/$session"
exit 0
