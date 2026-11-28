# Pranav's Marketplace

My Claude Code plugins.

| Plugin | What it is |
|---|---|
| [`assistant-worker`](plugins/assistant-worker/) | An assistant you talk to, one worker session per thread of work (in tmux it starts and checks on them itself), and a browser agent |
| [`fineline`](plugins/fineline/) | A two-line status line with thin bars: branch and model, then context and rate limits |
| [`skyline`](plugins/skyline/) | A token usage chart that goes below your existing status line: one bar per message, tokens per call |
| [`conventional-commits`](plugins/conventional-commits/) | Tells Claude to use Conventional Commits, and adds a git hook that rejects anything else |
| [`quietlint`](plugins/quietlint/) | Checks the files Claude edited at the end of each turn and stays silent unless there are problems; formats and lints on commit |
| [`clear-me-now`](plugins/clear-me-now/) | Say "I'm gonna clear you": Claude writes a handoff, you type `/clear` (in tmux it clears itself), and the fresh session carries on |

Install one:

```
/plugin marketplace add pranavkbd/pranavs-marketplace
/plugin install fineline@pranavs-marketplace
```

For example, to install assistant-worker:

```
/plugin marketplace add pranavkbd/pranavs-marketplace
/plugin install assistant-worker@pranavs-marketplace
```

Then follow [its README](plugins/assistant-worker/) to add the `assistant` and `worker` shell launchers.
