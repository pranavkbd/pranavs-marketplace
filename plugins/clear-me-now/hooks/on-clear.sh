#!/usr/bin/env bash
# SessionStart hook (after /clear): if the previous session left a handoff, tell the new session
# to read it before anything else.
. "$(dirname "$0")/../scripts/common.sh"
cat >/dev/null
f=$(pending_file)
[ -f "$f" ] || exit 0
handoff=$(sed -n 's/^handoff=//p' "$f")
marked=$(sed -n 's/^marked=//p' "$f")
rm -f "$f"
# a handoff marked more than a day ago is stale: ignore it
[ $(( $(date +%s) - ${marked:-0} )) -le 86400 ] || exit 0
[ -f "$handoff" ] || exit 0
cat <<EOF
The user just ran /clear to continue this work with a fresh context, using clear-me-now. Your
previous self wrote a handoff file for you: $handoff
This is now your handoff file: when the user says they are gonna clear you again, update this one.

Before anything else, whatever the user's first message is, read that file in full, plus any
documents it links that you need. Then continue the work from where it left off. Don't greet
the user or summarize the handoff back to them, and don't ask them for anything it already covers.
EOF
