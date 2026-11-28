# assistant-worker

You talk to one **assistant** session. It keeps your threads of work apart (A, B, C…), answers
side questions, pushes back on bad ideas, and briefs one **worker** session per thread. Workers
do the real work and report back with `QUESTION [C2]`, `UPDATE` and `DONE` messages, which the
assistant condenses for you. A **browser** agent (Haiku, read-only) drives Playwright so
screenshots and snapshots never fill anyone else's context.

## Install

```
/plugin marketplace add pranavkbd/pranavs-marketplace
/plugin install assistant-worker@pranavs-marketplace
```

Then add the launchers to `~/.zshrc` (path from `/plugin` → assistant-worker, or copy the file):

```zsh
source /path/to/assistant-worker/shell/claude-pair.zsh
```

## Use

In a repo, open two terminals:

```
assistant        # the one you talk to
worker           # thread A's worker
worker C         # thread C's worker, when the assistant asks for one
worker C --model sonnet   # cheaper, for iteration rounds
```

Sessions are named after the git checkout's top folder (`assistant-<dir>`, `worker-<dir>-c`),
so each pair finds the other and pairs in other checkouts don't clash.

## In tmux

Start the assistant inside tmux and it runs the workers itself; you don't need a second terminal.
Outside tmux nothing changes: it tells you what to run.

- **Starts workers** in background windows, named as the launchers name them, with the assistant's
  own permission mode. If the mode can't be determined, the worker isn't started.
- **Peeks** at a worker's screen: busy, idle or waiting, context %, a pending prompt, unsent input.
- **New round:** types `/clear` into the worker (only when it's idle with an empty input box), then
  sends the next brief. You type nothing.
- **Closes** the windows it opened once a thread is done.

Permission prompts and trust dialogs stay yours: the assistant tells you which window is asking and
never answers. In manual or accept-edits mode, it will also ask you before running these scripts.

A `SessionStart` hook loads [`TMUX-assistant.md`](TMUX-assistant.md) or
[`TMUX-worker.md`](TMUX-worker.md) into those two agents' sessions, only inside tmux. A second hook
records the assistant's permission mode before each Bash command, in `~/.claude/assistant-worker/`.

The scripts work by hand too (`tmux-spawn.sh` only from the assistant):

```
scripts/tmux-spawn.sh <dir> [letter] [--model <model>]
scripts/tmux-peek.sh <worker name> [lines]
scripts/tmux-clear-worker.sh <worker name>
```

Needs tmux and bash; tested with tmux 3.4 and Claude Code 2.1.332. State and clear detection read
Claude Code's session records (`~/.claude/sessions/`), which aren't a documented interface: if that
changes, peek falls back to reading the screen and clearing refuses. Context % is read from a status
line showing `ctx … N%` (such as [fineline](../fineline/)); otherwise it shows `?`.

## Rules the agents follow

- **One editor:** only one worker changes code at a time; every brief says whether it may.
- **Fresh worker per round:** at the end of a round the worker writes a handoff file, you type
  `/clear` in its terminal (in tmux the assistant does), and the next brief starts with "Read the
  handoff file first."
- **Pushback both ways:** the assistant and the workers say so when there's a simpler or safer way.

The browser agent needs the Playwright MCP server (`claude mcp add playwright -s user -- npx @playwright/mcp@latest`).
