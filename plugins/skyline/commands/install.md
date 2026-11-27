---
description: Install the skyline status line into ~/.claude
allowed-tools: Bash, Read, Edit
---

Install the skyline status line that ships with this plugin:

1. Copy `${CLAUDE_PLUGIN_ROOT}/skyline.sh` to `~/.claude/skyline-statusline.sh` and make it
   executable. If that file already exists and differs, back it up first to
   `~/.claude/skyline-statusline.sh.bak`.
2. In `~/.claude/settings.json`, set `statusLine` to
   `{ "type": "command", "command": "bash ~/.claude/skyline-statusline.sh" }`, keeping every
   other key. If `statusLine` already points at something else, say what it was so the user can
   switch back.
3. Say in one line what changed. The script needs `jq`; warn if `command -v jq` finds nothing.
   Mention that `STATUSLINE_CHART_WIDTH` and `STATUSLINE_CHART_ROWS` can be set in the `env`
   section of `~/.claude/settings.json`.
