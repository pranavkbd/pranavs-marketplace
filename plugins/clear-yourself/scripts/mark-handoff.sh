#!/usr/bin/env bash
# Record the handoff file for this session, so the session that starts after /clear reads it.
# Usage: mark-handoff.sh <handoff file>
set -e
. "$(dirname "$0")/common.sh"
handoff=${1:?usage: mark-handoff.sh <handoff file>}
[ -f "$handoff" ] || { echo "clear-yourself: handoff file not found: $handoff" >&2; exit 1; }
handoff=$(cd "$(dirname "$handoff")" && pwd)/$(basename "$handoff")
mkdir -p "$STATE_DIR"
printf 'handoff=%s\nmarked=%s\n' "$handoff" "$(date +%s)" > "$(pending_file)"
echo "clear-yourself: after /clear, the new session will start by reading $handoff"
