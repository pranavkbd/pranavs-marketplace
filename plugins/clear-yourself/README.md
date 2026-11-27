# clear-yourself

Long sessions get slow and expensive, because every step re-reads the whole conversation.
clear-yourself lets you reset one without losing your place:

1. You say **"clear yourself"**.
2. Claude checks whether now is a good time. If a subagent or command is still running, or it's
   halfway through a change, it says so and tells you when it will be ready.
3. Otherwise it writes or updates a **handoff document**: the goal, where things stand and the
   exact next step, decisions and why, your preferences and corrections, background on the
   topic, the files and docs that matter, how to run things, open questions and git state.
4. You type **`/clear`**, then **`go`**.
5. The fresh session is told to read the handoff before anything else, and carries on.

Typing `/clear` yourself is on purpose: it's your checkpoint, and a chance to read the handoff
first. Claude can't run `/clear` on itself.

## With assistant-worker

If the session is an `assistant` or a `worker`, the handoff also gets a **Sessions** section:
every session's exact name (from the ListAgents tool), what each worker is doing right now,
whether it may edit code, what it's waiting for, and open `QUESTION`/`ANSWER` IDs. The new
session is told to find them again with ListAgents and reach them with SendMessage.

## Where the handoff goes

In a `.local/` folder at the top of the repo (the current folder outside git, not `~/.local`):

- a new handoff gets its own file named after the topic, such as
  `.local/handoffs/skyline-plugin.md`, with `-2` added if that name is taken, so sessions
  sharing a repo never overwrite each other's handoffs;
- a session that started from a handoff updates that same file the next time it clears;
- a file you or the assistant named (a worker's `.local/handoff-c.md`) is always used as is.

`.local/` is kept out of git through `.git/info/exclude` if it isn't ignored already.

## Install

```
/plugin install clear-yourself@pranavs-marketplace
```

No setup. Tested in the terminal; it uses only a skill and a `SessionStart` hook, so it should
work the same in the IDE extensions and the desktop app.

## How the new session finds the handoff

When Claude finishes the handoff it runs `scripts/mark-handoff.sh`, which records the path in
`~/.claude/clear-yourself/`, keyed by the Claude Code process (`/clear` keeps the same process).
A `SessionStart` hook that only runs after `/clear` picks it up and tells the new session to read
it. Two sessions in the same folder don't mix up their handoffs, and a record older than a day is
ignored.
