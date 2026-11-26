# fineline

A two-line Claude Code status line with thin hairline bars (`━━━─────`).

- **Line 1:** git branch (with `*` when dirty, or the folder name outside git), local
  server/UI ports when they are listening, model and effort.
- **Line 2:** context-window bar, then 5-hour and 7-day rate-limit bars with time until reset.

```
main* | Opus 5.5 (high)
ctx ━━━───── 42% | 5h ━━────── 30% 2h00m | 7d ━━━━━─── 65% 3d11h
```

Needs `jq`.

## Install

```
/plugin install fineline@pranavs-marketplace
/fineline:install
```

`/fineline:install` copies `statusline.sh` to `~/.claude/statusline-command.sh` and points
`statusLine` in `~/.claude/settings.json` at it. Plugins can't set `statusLine` themselves,
so this step is needed.
