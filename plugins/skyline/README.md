# skyline

A token usage status line for Claude Code: a context bar, what your last message cost, and a
stacked bar chart of tokens per call for every message, one "building" per message.

```
▰▰▰▱▱▱▱▱ 34%  last: 3 calls × ~339.1k doc = 1.0M read (8.0k new) · 3.8k out
  50k                                                      ■ output
                                                           ■ new input
                                                           ■ re-read ÷20  (335.0k per call now)
  25k
      ▐█████▐███▐███▐▐▐▐█▐▐███▐██▐████▐███▐██▐██▐█▐▐█▐█▐█  59 messages
      ▐█████▐███▐███▐▐▐▐█▐▐███▐██▐████▐███▐██▐██▐█▐▐█▐█▐█  session 308.0k new · 172.1k out · 34.3M re-read total (all calls)
      ──────────────────────────────────────────────────────  154 calls
```

- **Line 1:** context-window bar, then the last message: calls × average document size = tokens
  read, how many were new, and output.
- **Chart:** one bar per message you sent. Width is the number of model calls it took (one column
  per call); height is average tokens per call, stacked as re-read (teal, divided by 20), new input
  (amber) and output (red).

Every call re-reads the whole conversation, so total re-read ≈ calls × document size. In a long
session that is most of your tokens, and the call count is the multiplier.

Needs `jq`. Subagent usage is not counted.

## Install

```
/plugin install skyline@pranavs-marketplace
/skyline:install
```

`/skyline:install` copies `skyline.sh` to `~/.claude/skyline-statusline.sh` and points
`statusLine` in `~/.claude/settings.json` at it. Plugins can't set `statusLine` themselves, so
this step is needed. It replaces any other status line, fineline included.

## Settings

Set these in the `env` section of `~/.claude/settings.json`:

| Variable | Default | Effect |
|---|---|---|
| `STATUSLINE_CHART_WIDTH` | terminal width − 80 (min 20) | Maximum chart width in calls; older messages scroll off |
| `STATUSLINE_CHART_ROWS` | `6` | Chart height in rows |

If you see thin dark lines between chart rows, set your terminal's line height to 1.0.

How it works, and the pitfalls it avoids, are in [SPEC.md](SPEC.md).
