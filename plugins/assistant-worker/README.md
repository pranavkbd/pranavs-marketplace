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

## Rules the agents follow

- **One editor:** only one worker changes code at a time; every brief says whether it may.
- **Fresh worker per round:** at the end of a round the worker writes a handoff file, you type
  `/clear` in its terminal, and the next brief starts with "Read the handoff file first."
- **Pushback both ways:** the assistant and the workers say so when there's a simpler or safer way.

The browser agent needs the Playwright MCP server (`claude mcp add playwright -s user -- npx @playwright/mcp@latest`).
