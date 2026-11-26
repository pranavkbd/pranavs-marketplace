---
description: Install the fineline status line into ~/.claude
allowed-tools: Bash, Read, Edit
---

Install the fineline status line that ships with this plugin:

1. Copy `${CLAUDE_PLUGIN_ROOT}/statusline.sh` to `~/.claude/statusline-command.sh`. If that file
   already exists and differs, back it up first to `~/.claude/statusline-command.sh.bak`.
2. In `~/.claude/settings.json`, set `statusLine` to
   `{ "type": "command", "command": "bash ~/.claude/statusline-command.sh" }`, keeping every other key.
3. Say in one line what changed. The script needs `jq`; warn if `command -v jq` finds nothing.
