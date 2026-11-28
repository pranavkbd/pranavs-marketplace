# clear-me-now in tmux

This session runs inside tmux, so when you run the clear-me-now skill you clear yourself. The user
types nothing. This only changes step 3 of the skill; steps 1 and 2 are the same, including saying
**not now**. Never do this unless the user said they are gonna clear you.

In step 3, after `mark-handoff.sh` succeeds, run this as your **last tool call**:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-clear.sh"
```

It types `/clear` into this pane, which runs when your turn ends, then `go` to the fresh session.
Replace the skill's closing lines with these, then stop:

> Handoff is in `<path>`. Clearing myself now, nothing to type.
>
> KLEAR ME NOW!

If either script fails, don't retry or send keys yourself: end the turn as the skill says, with the
user typing `/clear`.
