# Shared helpers for clear-yourself. Sourced, not run.
# A pending handoff is a file in $STATE_DIR named after the Claude Code process. /clear keeps the
# same process, so the script the agent runs before /clear and the SessionStart hook after it
# both find the same file, and two sessions in the same folder never pick up each other's.

STATE_DIR="$HOME/.claude/clear-yourself"

# Key for this session: the Claude Code process ID, found by walking up the parent chain.
# Falls back to the working directory if no Claude process is found.
session_key() {
  local p=$$ comm args
  while [ "$p" -gt 1 ]; do
    comm=$(ps -o comm= -p "$p" 2>/dev/null) || break
    case "${comm##*/}" in
      claude|claude.exe) printf 'pid-%s' "$p"; return ;;
      node) args=$(ps -o args= -p "$p" 2>/dev/null)
            case "$args" in *claude-code*|*/claude\ *|*/claude) printf 'pid-%s' "$p"; return ;; esac ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  printf 'dir-%s' "$(pwd | cksum | cut -d' ' -f1)"
}

pending_file() { printf '%s/%s.pending' "$STATE_DIR" "$(session_key)"; }
