---
description: Install the skyline token chart below your current status line
allowed-tools: Bash, Read, Edit, Write
---

Install the skyline status line that ships with this plugin. Skyline only draws the token chart. It goes **below** whatever status line the user already has.

1. Copy `${CLAUDE_PLUGIN_ROOT}/skyline.sh` to `~/.claude/skyline-statusline.sh` and make it
   executable. If that file already exists and differs, back it up first to
   `~/.claude/skyline-statusline.sh.bak`.
2. Read `statusLine.command` in `~/.claude/settings.json`.
   - If it is already `bash ~/.claude/statusline-stack.sh`, stop after step 1: the stack is set up.
   - If it is some other command, that is the user's own status line. Write
     `~/.claude/statusline-stack.sh` (executable), putting that command in place of `<TOP>`:

     ```bash
     #!/usr/bin/env bash
     # Status line: your own status line on top, the skyline token chart below it.
     input=$(cat)
     top=$(printf '%s' "$input" | <TOP> 2>/dev/null)
     sky=$(printf '%s' "$input" | bash ~/.claude/skyline-statusline.sh 2>/dev/null)
     # a Braille blank (U+2800) spacer line between the two: Claude Code may drop a truly empty line
     if [ -n "$top" ] && [ -n "$sky" ]; then printf '%s\n⠀\n%s' "$top" "$sky"; else printf '%s%s' "$top" "$sky"; fi
     ```

     Then set `statusLine` to `{ "type": "command", "command": "bash ~/.claude/statusline-stack.sh" }`.
   - If there is no `statusLine`, set it to
     `{ "type": "command", "command": "bash ~/.claude/skyline-statusline.sh" }`.

   Keep every other key in `settings.json`.
3. Say in one line what changed, including which status line now sits on top. The script needs
   `jq`; warn if `command -v jq` finds nothing. Mention that `STATUSLINE_CHART_WIDTH` and
   `STATUSLINE_CHART_ROWS` can be set in the `env` section of `~/.claude/settings.json`.
